#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/nh"
curl -fsSL "https://raw.githubusercontent.com/j-haacker/dotfiles/dev/nh.sh" -o "$HOME/.config/nh/nh.sh"
curl -fsSL "https://raw.githubusercontent.com/j-haacker/dotfiles/dev/archive_nh_logs.sh" -o "$HOME/.config/nh/archive_nh_logs.sh"
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
