#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CODEX_HOME:-$HOME/.codex}"
SKILLS_TARGET="$TARGET_DIR/skills"

SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="codex-config-update.service"
TIMER_NAME="codex-config-update.timer"

backup_and_link() {
    local source="$1"
    local target="$2"

    # Already linked correctly.
    if [[ -L "$target" ]] &&
       [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
        echo "OK:   $target"
        return
    fi

    # Preserve anything already present.
    if [[ -e "$target" || -L "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
        echo "BACK: $target -> $backup"
        mv -- "$target" "$backup"
    fi

    echo "LINK: $target -> $source"
    ln -s -- "$source" "$target"
}


install_links() {
    mkdir -p "$TARGET_DIR" "$SKILLS_TARGET"

    backup_and_link \
        "$SOURCE_DIR/AGENTS.md" \
        "$TARGET_DIR/AGENTS.md"

    if [[ -d "$SOURCE_DIR/skills" ]]; then
        for skill in "$SOURCE_DIR"/skills/*; do
            [[ -d "$skill" ]] || continue

            backup_and_link \
                "$skill" \
                "$SKILLS_TARGET/$(basename "$skill")"
        done
    fi
}


update_repository() {
    local repo_root

    if ! repo_root="$(git -C "$SOURCE_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
        echo "ERROR: $SOURCE_DIR is not inside a Git repository." >&2
        exit 1
    fi

    echo "Updating repository:"
    echo "  $repo_root"

    git -C "$repo_root" pull --ff-only

    install_links
}


install_systemd_timer() {
    mkdir -p "$SYSTEMD_DIR"

    cat > "$SYSTEMD_DIR/$SERVICE_NAME" <<EOF
[Unit]
Description=Update Codex configuration

[Service]
Type=oneshot
ExecStart=$SOURCE_DIR/install.sh --update
EOF

    cat > "$SYSTEMD_DIR/$TIMER_NAME" <<'EOF'
[Unit]
Description=Periodically update Codex configuration

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now "$TIMER_NAME"

    echo "Enabled systemd timer:"
    echo "  $TIMER_NAME"
}


case "${1:-}" in
    --update)
        update_repository
        ;;

    "")
        install_links
        install_systemd_timer

        echo
        echo "Codex configuration installed from:"
        echo "  $SOURCE_DIR"
        ;;

    *)
        echo "Usage: $0 [--update]" >&2
        exit 2
        ;;
esac