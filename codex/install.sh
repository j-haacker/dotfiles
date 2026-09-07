#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CODEX_HOME:-$HOME/.codex}"
# The service runs from a different working directory.
TARGET_DIR="$(realpath -m -- "$TARGET_DIR")"
SKILLS_TARGET="$TARGET_DIR/skills"

SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="codex-config-update.service"
TIMER_NAME="codex-config-update.timer"

backup_existing() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        local backup
        backup="$(mktemp -d -- "${target}.bak.XXXXXX")"
        echo "BACK: $target -> $backup/original"
        mv -T -- "$target" "$backup/original"
    fi
}

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
    backup_existing "$target"

    echo "LINK: $target -> $source"
    ln -s -- "$source" "$target"
}


install_links() {
    if [[ -L "$SKILLS_TARGET" || ! -d "$SKILLS_TARGET" ]]; then
        backup_existing "$SKILLS_TARGET"
    fi
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


# Quote a systemd string, including literal specifiers and control characters.
systemd_quote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//%/%%}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '"%s"' "$value"
}

install_systemd_timer() {
    mkdir -p "$SYSTEMD_DIR"
    local staging unit
    staging="$(mktemp -d -- "$SYSTEMD_DIR/.codex-config.XXXXXX")"

    cat > "$staging/$SERVICE_NAME" <<EOF
[Unit]
Description=Update Codex configuration

[Service]
Type=oneshot
Environment=$(systemd_quote "CODEX_HOME=$TARGET_DIR")
# Disable environment expansion in the literal installer path.
ExecStart=:bash $(systemd_quote "$SOURCE_DIR/install.sh") --update
EOF

    cat > "$staging/$TIMER_NAME" <<'EOF'
[Unit]
Description=Periodically update Codex configuration

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF

    for unit in "$SERVICE_NAME" "$TIMER_NAME"; do
        if ! cmp -s -- "$staging/$unit" "$SYSTEMD_DIR/$unit"; then
            backup_existing "$SYSTEMD_DIR/$unit"
            mv -T -- "$staging/$unit" "$SYSTEMD_DIR/$unit"
        fi
    done
    rm -r -- "$staging"

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
