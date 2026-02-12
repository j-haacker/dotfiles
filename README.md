# dotfiles
Personal shell utils

## nh.sh
`nh` runs a command with `nohup` in the background and writes output to a timestamped log file (for example: `nohup__my_command__20260212-112753.log`).

### Download + install
Run this from any shell:

```bash
curl -fsSL https://raw.githubusercontent.com/j-haacker/dotfiles/main/install_nh.sh | bash
```

This installs `nh.sh` to `~/.config/nh/nh.sh`, adds a `source` line to `~/.zshrc` or `~/.bashrc`, and prints which file was updated.

Restart your shell, or load it now:

```bash
source ~/.zshrc   # or: source ~/.bashrc
```
