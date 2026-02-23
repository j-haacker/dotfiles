#!/usr/bin/env bash
set -euo pipefail

trim_spaces() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

normalize_cutoff_expr() {
  local expr
  expr="$(trim_spaces "$1")"

  if [[ "$expr" =~ ^[0-9]+[[:space:]]+(second|seconds|sec|secs|minute|minutes|min|mins|hour|hours|day|days|week|weeks|month|months|year|years)$ ]]; then
    printf '%s ago' "$expr"
    return
  fi

  printf '%s' "$expr"
}

parse_cutoff_epoch() {
  local normalized
  normalized="$(normalize_cutoff_expr "$1")"
  date -d "$normalized" +%s 2>/dev/null
}

path_matches_exclude() {
  local path="$1"
  local root="$2"
  local pattern="$3"
  local rel

  if [[ "$path" == "$root"/* ]]; then
    rel="${path#$root/}"
  else
    rel="${path##*/}"
  fi

  # Absolute path pattern.
  if [[ "$pattern" == /* ]]; then
    if [[ "$pattern" == */ ]]; then
      pattern="${pattern%/}"
      [[ "$path" == "$pattern" || "$path" == "$pattern/"* ]]
      return
    fi
    [[ "$path" == $pattern ]]
    return
  fi

  # Directory-style pattern.
  if [[ "$pattern" == */ ]]; then
    pattern="${pattern%/}"
    [[ "$rel" == "$pattern" || "$rel" == "$pattern/"* || "$rel" == */"$pattern" || "$rel" == */"$pattern/"* ]]
    return
  fi

  # File/path glob pattern.
  [[ "$rel" == $pattern || "$rel" == */$pattern || "${path##*/}" == $pattern ]]
}

should_exclude_path() {
  local path="$1"
  local root="$2"
  local pattern

  for pattern in "${exclude_patterns[@]}"; do
    pattern="$(trim_spaces "$pattern")"
    if [[ -z "$pattern" || "$pattern" == \#* ]]; then
      continue
    fi
    if path_matches_exclude "$path" "$root" "$pattern"; then
      return 0
    fi
  done

  return 1
}

load_ignore_patterns() {
  local file_path="$1"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim_spaces "$line")"
    if [[ -z "$line" || "$line" == \#* ]]; then
      continue
    fi
    exclude_patterns+=("$line")
  done < "$file_path"
}

usage() {
  cat <<'EOF'
Usage: archive_nh_logs.sh [options] [cutoff] [search-root ...]

Archive nh.sh log files older than the cutoff into a rolling tar.gz archive.

Arguments:
  cutoff             Optional. Date/time understood by `date -d`, or a bare timedelta like "1 week".
                     Bare timedeltas are interpreted as "... ago". Default cutoff is "1 week".
  search-root        Optional one or more directories to scan recursively (default: current directory).

Options:
  --exclude <pattern>    Exclude files/paths by glob-like pattern. Repeatable.
  --ignore-file <path>   Read excludes from file. Defaults to "./.nhignore" when present.
  --no-ignore-file       Ignore ".nhignore" for this run.

Archive output:
  Writes/updates "nohup_outdated_logs.tar.gz" in the current directory.
  Only log files owned by the current user are considered.
  Logs are stored with absolute paths.
  Only newly archived files are removed from disk, and only after archive validation succeeds.

Examples:
  archive_nh_logs.sh --exclude "scripts/tmp/" --exclude "*_debug*.log"
  archive_nh_logs.sh
  archive_nh_logs.sh "1 week"
  archive_nh_logs.sh "2026-02-01 13:00:00" .
  archive_nh_logs.sh "2026-02-01 13:00:00" "$HOME/project-a" "$HOME/project-b"
EOF
}

exclude_patterns=()
ignore_file="$PWD/.nhignore"
ignore_file_explicit=0
positional_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --exclude)
      if [[ $# -lt 2 ]]; then
        printf 'Missing value for --exclude\n' >&2
        exit 1
      fi
      exclude_patterns+=("$2")
      shift 2
      ;;
    --exclude=*)
      exclude_patterns+=("${1#*=}")
      shift
      ;;
    --ignore-file)
      if [[ $# -lt 2 ]]; then
        printf 'Missing value for --ignore-file\n' >&2
        exit 1
      fi
      ignore_file="$2"
      ignore_file_explicit=1
      shift 2
      ;;
    --ignore-file=*)
      ignore_file="${1#*=}"
      ignore_file_explicit=1
      shift
      ;;
    --no-ignore-file)
      ignore_file=""
      shift
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        positional_args+=("$1")
        shift
      done
      ;;
    --*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      positional_args+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$ignore_file" && "$ignore_file" != /* ]]; then
  ignore_file="$PWD/$ignore_file"
fi

if [[ -n "$ignore_file" && -f "$ignore_file" ]]; then
  load_ignore_patterns "$ignore_file"
elif [[ "$ignore_file_explicit" -eq 1 ]]; then
  printf 'Ignore file not found: %s\n' "$ignore_file" >&2
  exit 1
fi

set -- "${positional_args[@]}"

default_cutoff_input="1 week"
archive_path="$PWD/nohup_outdated_logs.tar.gz"
archive_dir="$(dirname "$archive_path")"
current_uid="$(id -u)"
matching_owned_log_count=0
excluded_log_count=0

cutoff_input="$default_cutoff_input"
if [[ $# -gt 0 ]] && cutoff_epoch="$(parse_cutoff_epoch "$1")"; then
  cutoff_input="$1"
  shift
elif ! cutoff_epoch="$(parse_cutoff_epoch "$cutoff_input")"; then
  printf 'Invalid default cutoff date: %s\n' "$cutoff_input" >&2
  exit 1
fi

cutoff_stamp="$(date -d "@$cutoff_epoch" +%Y%m%d-%H%M%S)"
cutoff_expr="$(normalize_cutoff_expr "$cutoff_input")"

if [[ $# -gt 0 ]]; then
  search_roots=("$@")
else
  search_roots=("$PWD")
fi

mkdir -p "$archive_dir"

tmp_dir="$(mktemp -d "$archive_dir/.archive_nh_logs.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

candidate_files="$tmp_dir/candidate_files.txt"
existing_entries="$tmp_dir/existing_entries.txt"
new_files="$tmp_dir/new_files.txt"
new_tar="$tmp_dir/new_files.tar"
base_tar="$tmp_dir/base_archive.tar"
updated_archive="$tmp_dir/nohup_outdated_logs.tar.gz"

: > "$candidate_files"
: > "$existing_entries"
: > "$new_files"

for root in "${search_roots[@]}"; do
  if [[ "$root" != /* ]]; then
    root="$PWD/$root"
  fi

  if [[ ! -d "$root" ]]; then
    printf 'Skipping missing directory: %s\n' "$root" >&2
    continue
  fi

  while IFS= read -r -d '' file; do
    filename="${file##*/}"
    if [[ "$filename" =~ __([0-9]{8}-[0-9]{6})\.log$ ]]; then
      matching_owned_log_count=$((matching_owned_log_count + 1))
      if should_exclude_path "$file" "$root"; then
        excluded_log_count=$((excluded_log_count + 1))
        continue
      fi
      log_stamp="${BASH_REMATCH[1]}"
      if [[ "$log_stamp" < "$cutoff_stamp" ]]; then
        printf '%s\n' "$file" >> "$candidate_files"
      fi
    fi
  done < <(find "$root" -type f -uid "$current_uid" -name 'nohup__*.log' -print0 2>/dev/null)
done

sort -u -o "$candidate_files" "$candidate_files"

if [[ ! -s "$candidate_files" ]]; then
  if [[ "$matching_owned_log_count" -gt 0 ]]; then
    if [[ "$excluded_log_count" -eq "$matching_owned_log_count" ]]; then
      printf 'Found %s owned nh logs, but all were excluded by filters.\n' "$matching_owned_log_count"
    elif [[ "$excluded_log_count" -gt 0 ]]; then
      printf 'Found %s owned nh logs (%s excluded), but none older than cutoff "%s".\n' "$matching_owned_log_count" "$excluded_log_count" "$cutoff_expr"
    else
      printf 'Found %s owned nh logs, but none older than cutoff "%s".\n' "$matching_owned_log_count" "$cutoff_expr"
    fi
  else
    printf 'No owned nh logs were found in the selected search roots.\n'

    # Shared drives may surface logs as another owner; warn when that is detected.
    found_unowned_logs=0
    for root in "${search_roots[@]}"; do
      if [[ "$root" != /* ]]; then
        root="$PWD/$root"
      fi
      if [[ ! -d "$root" ]]; then
        continue
      fi
      if find "$root" -type f -name 'nohup__*.log' ! -uid "$current_uid" -print -quit 2>/dev/null | grep -q .; then
        found_unowned_logs=1
        break
      fi
    done

    if [[ "$found_unowned_logs" -eq 1 ]]; then
      printf 'Found nh logs owned by other users; they are skipped by design.\n' >&2
    fi
  fi

  printf 'Search roots: %s\n' "${search_roots[*]}"
  exit 0
fi

if [[ -f "$archive_path" ]]; then
  if ! tar -tzf "$archive_path" > "$existing_entries" 2>/dev/null; then
    printf 'Existing archive is unreadable: %s\n' "$archive_path" >&2
    exit 1
  fi
  sort -u -o "$existing_entries" "$existing_entries"
fi

if [[ -s "$existing_entries" ]]; then
  comm -23 "$candidate_files" "$existing_entries" > "$new_files"
else
  cp "$candidate_files" "$new_files"
fi

if [[ ! -s "$new_files" ]]; then
  printf 'No new nh logs to archive. Existing archive already contains all eligible files.\n'
  exit 0
fi

tar --create --file "$new_tar" --absolute-names --files-from "$new_files"

if [[ -f "$archive_path" ]]; then
  gzip -dc "$archive_path" > "$base_tar"
  tar --concatenate --file "$base_tar" "$new_tar"
  gzip -c "$base_tar" > "$updated_archive"
else
  gzip -c "$new_tar" > "$updated_archive"
fi

if ! tar -tzf "$updated_archive" >/dev/null 2>&1; then
  printf 'New archive validation failed; source logs were not deleted.\n' >&2
  exit 1
fi

mv "$updated_archive" "$archive_path"

archived_count="$(wc -l < "$new_files" | tr -d '[:space:]')"
deleted_count=0
delete_failures=0
while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    if rm -f -- "$file"; then
      deleted_count=$((deleted_count + 1))
    else
      printf 'Failed to delete archived log: %s\n' "$file" >&2
      delete_failures=$((delete_failures + 1))
    fi
  fi
done < "$new_files"

printf 'Archived %s new files to %s\n' "$archived_count" "$archive_path"
printf 'Deleted %s archived source files\n' "$deleted_count"

if [[ "$delete_failures" -gt 0 ]]; then
  printf 'Warning: %s archived files could not be deleted.\n' "$delete_failures" >&2
  exit 1
fi
