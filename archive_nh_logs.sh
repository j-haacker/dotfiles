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

usage() {
  cat <<'EOF'
Usage: archive_nh_logs.sh [cutoff] [search-root ...]

Archive nh.sh log files older than the cutoff into a rolling tar.gz archive.

Arguments:
  cutoff             Optional. Date/time understood by `date -d`, or a bare timedelta like "1 week".
                     Bare timedeltas are interpreted as "... ago". Default cutoff is "1 week".
  search-root        Optional one or more directories to scan (default: current directory).

Archive output:
  Writes/updates "nohup_outdated_logs.tar.gz" in the current directory.
  Only log files owned by the current user are considered.
  Logs are stored with absolute paths.
  Only newly archived files are removed from disk, and only after archive validation succeeds.

Examples:
  archive_nh_logs.sh
  archive_nh_logs.sh "1 week"
  archive_nh_logs.sh "2026-02-01 13:00:00" .
  archive_nh_logs.sh "2026-02-01 13:00:00" "$HOME/project-a" "$HOME/project-b"
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == --* ]]; then
  printf 'Unknown option: %s\n' "$1" >&2
  usage >&2
  exit 1
fi

default_cutoff_input="1 week"
archive_path="$PWD/nohup_outdated_logs.tar.gz"
archive_dir="$(dirname "$archive_path")"
current_uid="$(id -u)"

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
      log_stamp="${BASH_REMATCH[1]}"
      if [[ "$log_stamp" < "$cutoff_stamp" ]]; then
        printf '%s\n' "$file" >> "$candidate_files"
      fi
    fi
  done < <(find "$root" -type f -uid "$current_uid" -name 'nohup__*.log' -print0 2>/dev/null)
done

sort -u -o "$candidate_files" "$candidate_files"

if [[ ! -s "$candidate_files" ]]; then
  printf 'No nh logs older than cutoff "%s" were found.\n' "$cutoff_expr"
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
