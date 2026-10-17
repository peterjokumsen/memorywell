# shellcheck shell=bash
# Logging backend selection. Sourced by common.sh before anything calls a
# printer. The two backends define an identical set of functions:
#   step info success warn error debug group endgroup
#
# LOG_FORMAT picks one explicitly:
#   auto    (default) GitHub Actions backend when GITHUB_ACTIONS=true, else local
#   github  force workflow commands (useful for eyeballing CI output locally)
#   local   force the TTY/colour backend
# LOG_FORMAT is only read when unset, so an explicit choice always wins.
if [[ -z "${LOG_FORMAT:-}" ]]; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    LOG_FORMAT="github"
  else
    LOG_FORMAT="local"
  fi
fi

_LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$LOG_FORMAT" in
  local)
    # shellcheck source=log-local.sh
    source "${_LOG_DIR}/log-local.sh"
    ;;
  github)
    # shellcheck source=log-ghactions.sh
    source "${_LOG_DIR}/log-ghactions.sh"
    ;;
  *)
    printf 'Unknown LOG_FORMAT: %s (expected auto, local or github)\n' "$LOG_FORMAT" >&2
    return 1 2>/dev/null || exit 1
    ;;
esac
