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

`$HOME/nohup_outdated_logs.tar.gz`

Behavior:
- Default cutoff is `1 week` (interpreted as `1 week ago`).
- Bare timedeltas like `1 week`, `2 days`, and `3 months` are accepted.
- Absolute/relative `date -d` expressions are accepted.
- Only logs owned by the current user are considered (useful on shared drives).
- Archive entries are stored with absolute paths.
- Only files newly added to the archive in the current run are deleted from disk, and only after archive validation succeeds.

Usage:

```bash
./archive_nh_logs.sh [cutoff] [search-root ...]
```

Examples:

```bash
# Default: archive logs older than 1 week from $HOME
./archive_nh_logs.sh

# Explicit timedelta cutoff
./archive_nh_logs.sh "2 weeks"

# Absolute date cutoff and custom roots
./archive_nh_logs.sh "2026-02-01 13:00:00" "$HOME" "/var/tmp"
```
