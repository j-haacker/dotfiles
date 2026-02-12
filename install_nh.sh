#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/nh"
curl -fsSL "https://raw.githubusercontent.com/j-haacker/dotfiles/main/nh.sh" -o "$HOME/.config/nh/nh.sh"

if [ -n "${ZSH_VERSION:-}" ]; then
  rc="$HOME/.zshrc"
else
  rc="$HOME/.bashrc"
fi

line='[ -f "$HOME/.config/nh/nh.sh" ] && source "$HOME/.config/nh/nh.sh"'
grep -Fqx "$line" "$rc" 2>/dev/null || echo "$line" >> "$rc"

echo "Installed. Restart shell or run: source $rc"
