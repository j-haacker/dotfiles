nh() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: nh <command> [args...]"
    return 1
  fi

  local slug ts log
  slug="$(printf '%s' "$*" | tr -cs '[:alnum:]' '_' | sed 's/^_//; s/_$//')"
  ts="$(date +%Y%m%d-%H%M%S)"
  log="nohup__${slug}__${ts}.log"

  nohup "$@" >| "$log" 2>&1 &
  echo "Started PID $! -> $log"
}
