# shellcheck shell=bash
# GitHub Actions logging backend: workflow commands instead of colour, so
# messages become annotations and verbose sections can be collapsed.
# Sourced by log.sh, never directly. See log-local.sh for the local
# counterpart — both must define the same functions, which the `shell` job in
# .github/workflows/ci.yml checks.
#
# Everything goes to STDERR, deliberately. Two reasons:
#   * The scripts treat stdout as data: `run`, `group_exists` and
#     `fetch_deployment_outputs` are called inside $(...) captures, and
#     check-state.sh prints its report there. Keeping annotations on stdout
#     would splice `::error::…` text into a captured value.
#   * The runner parses workflow commands from both streams (it attaches the
#     same output manager to the process's stdout and stderr), even though the
#     docs only promise stdout. Both streams are rendered in the log, so this
#     is annotation-safe in the runner and never corrupts captured output.
# If a future runner ever stops parsing stderr, the log stays readable and only
# the annotations are lost — which is why messages carry no colour of their own.
#
# Two parser rules to respect: the command ends at the first unescaped newline
# or `\r`, and `%` starts an escape sequence, so both are percent-encoded here.

# _gh_escape_data <text>: escape a workflow command's message payload.
_gh_escape_data() {
  local text="$*"
  text="${text//'%'/'%25'}"
  text="${text//$'\r'/'%0D'}"
  text="${text//$'\n'/'%0A'}"
  printf '%s' "$text"
}

# _gh_escape_prop <text>: escape a workflow command property value (title=,
# file=, ...), which additionally reserves the `:` and `,` separators.
# Unused for now — no printer takes properties — but kept next to the data
# escaper so adding a `title=` later cannot pick the wrong one.
_gh_escape_prop() {
  local text
  text="$(_gh_escape_data "$@")"
  text="${text//':'/'%3A'}"
  text="${text//','/'%2C'}"
  printf '%s' "$text"
}

# GitHub has no "success" annotation level: every non-error, non-warning level
# (step/info/success/debug) is a notice, colourised by the UI itself.
step()    { printf '::notice::%s\n' "$(_gh_escape_data "$*")" >&2; }
info()    { printf '::notice::%s\n' "$(_gh_escape_data "$*")" >&2; }
success() { printf '::notice::%s\n' "$(_gh_escape_data "$*")" >&2; }
warn()    { printf '::warning::%s\n' "$(_gh_escape_data "$*")" >&2; }
error()   { printf '::error::%s\n' "$(_gh_escape_data "$*")" >&2; }
# Only visible when step debug logging is on (ACTIONS_STEP_DEBUG / the
# "Enable debug logging" workflow setting).
debug()   { printf '::debug::%s\n' "$(_gh_escape_data "$*")" >&2; }

group()    { printf '::group::%s\n' "$(_gh_escape_data "$*")" >&2; }
endgroup() { printf '%s\n' '::endgroup::' >&2; }
