#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_URL="https://codeload.github.com/j-haacker/dotfiles/tar.gz/refs/heads/main"
DATA_DIR="$HOME/.local/share/codex-config"
SOURCE_DIR="$DATA_DIR/current"
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


update_copy() {
    local previous="" snapshot
    snapshot="$(mktemp -d -- "$DATA_DIR/.snapshot.XXXXXX")"
    # A failed download or extraction must leave the current copy usable.
    trap "rm -rf -- $(printf '%q' "$snapshot")" EXIT
    curl -fsSL "$ARCHIVE_URL" -o "$snapshot/archive.tar.gz"
    mkdir "$snapshot/content"
    tar -xzf "$snapshot/archive.tar.gz" -C "$snapshot/content" \
        --strip-components=2 --wildcards '*/codex/*'
    rm -- "$snapshot/archive.tar.gz"
    if [[ ! -f "$snapshot/content/AGENTS.md" ||
          ! -d "$snapshot/content/skills" ||
          ! -f "$snapshot/content/install.sh" ]]; then
        echo "ERROR: GitHub archive is missing the Codex configuration." >&2
        return 1
    fi
    bash -n "$snapshot/content/install.sh"

    if [[ -L "$SOURCE_DIR" ]]; then
        previous="$(readlink -- "$SOURCE_DIR")"
    fi
    if [[ "$previous" != "$DATA_DIR"/.snapshot.??????/content ]]; then
        backup_existing "$SOURCE_DIR"
        previous=""
    fi
    ln -s -- "$snapshot/content" "$snapshot/current"
    mv -Tf -- "$snapshot/current" "$SOURCE_DIR"
    trap - EXIT
    install_links

    # Only remove snapshots created by this installer, after links are refreshed.
    if [[ -n "$previous" ]]; then
        rm -rf -- "${previous%/content}"
    fi
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
    ""|--update) ;;
    *)
        echo "Usage: $0 [--update]" >&2
        exit 2
        ;;
esac

mkdir -p "$DATA_DIR"
# Serialize timer updates and manual installations.
exec 9> "$DATA_DIR/.lock"
flock 9
update_copy
if [[ "${1:-}" != --update ]]; then
    install_systemd_timer
fi
echo "Codex configuration synchronized from GitHub into $SOURCE_DIR"
