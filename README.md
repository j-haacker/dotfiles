# dotfiles
Personal shell utils

## nh.sh
`nh` runs a command with `nohup` in the background and writes output to a timestamped log file (for example: `nohup__my_command__20260212-112753.log`).

### Download + install
Run this from any shell:

```bash
curl -fsSL https://raw.githubusercontent.com/j-haacker/dotfiles/main/install_nh.sh | bash
```

This installs `nh.sh` and `archive_nh_logs.sh` to `~/.config/nh/`, adds a `source` line plus `archive_nh_logs` alias to `~/.zshrc` or `~/.bashrc`, and prints which file was updated.

Restart your shell, or load it now:

```bash
source ~/.zshrc   # or: source ~/.bashrc
```

## archive_nh_logs.sh
`archive_nh_logs.sh` archives `nh` log files older than a cutoff into a rolling compressed archive at:

`./nohup_outdated_logs.tar.gz` (current working directory)

Behavior:
- Default cutoff is `1 week` (interpreted as `1 week ago`).
- Bare timedeltas like `1 week`, `2 days`, and `3 months` are accepted.
- Absolute/relative `date -d` expressions are accepted.
- Only logs owned by the current user are considered (useful on shared drives).
- Archive entries are stored with absolute paths.
- Only files newly added to the archive in the current run are deleted from disk, and only after archive validation succeeds.
- Default recursive scan root is the current working directory, so each project root can keep its own archive.
- Exclusions can be defined with `--exclude` and in `.nhignore` (if present in current directory).

Usage:

```bash
./archive_nh_logs.sh [options] [cutoff] [search-root ...]
```

`search-root` directories are scanned recursively.

Options:
- `--exclude <pattern>`: exclude a path pattern (repeatable).
- `--ignore-file <path>`: read exclude patterns from a file.
- `--no-ignore-file`: disable reading `./.nhignore` for the run.

Ignore patterns:
- Blank lines and `#` comments are ignored.
- `dir/` excludes that directory recursively.
- Other patterns are glob-like matches against relative paths and basenames.

Examples:

```bash
# Default: archive logs older than 1 week from current directory
./archive_nh_logs.sh

# Explicit timedelta cutoff
./archive_nh_logs.sh "2 weeks"

# Absolute date cutoff and custom roots
./archive_nh_logs.sh "2026-02-01 13:00:00" "$HOME" "/var/tmp"

# Exclude paths from CLI
./archive_nh_logs.sh --exclude "scripts/tmp/" --exclude "*_debug*.log"

# Use .nhignore in the current directory (auto-loaded if present)
cat > .nhignore <<'EOF'
scripts/tmp/
*_debug*.log
EOF
./archive_nh_logs.sh
```
