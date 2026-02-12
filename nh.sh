# CREDIT: created with ChatGPT

_nh_needs_shell() {
  # Detect common shell operators in provided args.
  local s="$*"
  [[ "$s" == *'>'*  || "$s" == *'<'*  || "$s" == *'|'* ||
     "$s" == *';'*  || "$s" == *'&&'* || "$s" == *'||'* ]]
}

nh() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: nh <command> [args...]" >&2
    return 1
  fi

  local cmd slug ts log
  cmd="$*"
  slug="$(printf '%s' "$cmd" | tr -cs '[:alnum:]' '_' | sed 's/^_//; s/_$//')"
  ts="$(date +%Y%m%d-%H%M%S)"
  log="nohup__${slug}__${ts}.log"

  if _nh_needs_shell "$@"; then
    # shell mode: supports redirection/pipes/etc
    nohup bash -lc "$cmd" >| "$log" 2>&1 &
  else
    # argv mode: preserves argument boundaries
    nohup "$@" >| "$log" 2>&1 &
  fi

  if [ -w /dev/tty ]; then
    printf 'Started PID %s -> %s\n' "$!" "$log" > /dev/tty
  else
    printf 'Started PID %s -> %s\n' "$!" "$log" >&2
  fi
}
