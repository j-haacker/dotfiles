#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/.config/nh"

if [[ -f "$script_dir/nh.sh" && -f "$script_dir/archive_nh_logs.sh" ]]; then
  cp "$script_dir/nh.sh" "$HOME/.config/nh/nh.sh"
  cp "$script_dir/archive_nh_logs.sh" "$HOME/.config/nh/archive_nh_logs.sh"
else
  curl -fsSL "https://raw.githubusercontent.com/j-haacker/dotfiles/main/nh.sh" -o "$HOME/.config/nh/nh.sh"
  curl -fsSL "https://raw.githubusercontent.com/j-haacker/dotfiles/main/archive_nh_logs.sh" -o "$HOME/.config/nh/archive_nh_logs.sh"
fi

chmod +x "$HOME/.config/nh/archive_nh_logs.sh"

if [ -n "${ZSH_VERSION:-}" ]; then
  rc="$HOME/.zshrc"
else
  rc="$HOME/.bashrc"
fi

line='[ -f "$HOME/.config/nh/nh.sh" ] && source "$HOME/.config/nh/nh.sh"'
grep -Fqx "$line" "$rc" 2>/dev/null || echo "$line" >> "$rc"

archive_line='alias archive_nh_logs="$HOME/.config/nh/archive_nh_logs.sh"'
grep -Fqx "$archive_line" "$rc" 2>/dev/null || echo "$archive_line" >> "$rc"

echo "Installed nh.sh and archive_nh_logs.sh. Restart shell or run: source $rc"
