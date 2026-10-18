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
# Every line goes through _log_stderr, which also appends it to the stderr log.

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

# Every level writes twice, to two places that serve different readers:
#
#   * the step's text log (plain, via _log_stderr) — the full trace, for when
#     you are actually debugging and need the sequence.
#   * the workflow run summary ($GITHUB_STEP_SUMMARY) — one document that
#     renders above the log, where the answer is actually read.
#
# Annotations alone are not enough for the summary: each one renders as an
# isolated single line, so a run's notes arrive as a pile of disconnected
# one-liners instead of a readable transcript. Keeping only the problems as
# annotations, and letting the summary carry the narrative, fixes that — and
# keeps annotations meaning "something needs attention":
#
#   step    -> `## heading` + plain log    (milestone)
#   success -> summary bullet + plain log  (outcome)
#   info    -> plain log only              (chattiest; would flood the summary)
#   warn    -> summary bullet + ::warning::
#   error   -> summary bullet + ::error::
#   debug   -> ::debug:: (only with step debug logging on)
#
# A step is the one level that gets a real markdown heading, because that is
# what the summary is scanned for: the milestones of the run as an outline, with
# the outcomes and problems as bullets underneath. The rest would all be bullets
# otherwise, which is a list with no shape.
#
# Summary lines are flattened to one line each, so a message containing a
# newline cannot break the list item or the heading.
_summary_line() {
  local label="$1" message="$2"
  if [[ -z "${GITHUB_STEP_SUMMARY:-}" ]]; then
    return 0
  fi
  message="${message//$'\n'/ }"
  printf -- '- **%s** %s\n' "$label" "$message" >> "$GITHUB_STEP_SUMMARY"
}

# Leading blank line: a heading needs one before it, or markdown keeps it inside
# the preceding list item or table.
_summary_heading() {
  if [[ -z "${GITHUB_STEP_SUMMARY:-}" ]]; then
    return 0
  fi
  local message="${1//$'\n'/ }"
  printf '\n## %s\n' "$message" >> "$GITHUB_STEP_SUMMARY"
}

step() {
  _summary_heading "$*"
  _log_stderr "$*"
}
success() {
  _summary_line "done" "$*"
  _log_stderr "$*"
}
warn() {
  _summary_line "warn" "$*"
  _log_stderr "::warning::$(_gh_escape_data "$*")"
}
error() {
  _summary_line "error" "$*"
  _log_stderr "::error::$(_gh_escape_data "$*")"
}
# Only visible when step debug logging is on (ACTIONS_STEP_DEBUG / the
# "Enable debug logging" workflow setting).
debug() { _log_stderr "::debug::$(_gh_escape_data "$*")"; }

info() { _log_stderr "$*"; }

# group/endgroup bracket a verbose section. The start is a summary bullet so the
# collapsed section is still visible as a heading there; the end is not worth a
# line of its own.
group() {
  _summary_line "section" "$*"
  _log_stderr "::group::$(_gh_escape_data "$*")"
}
endgroup() { _log_stderr '::endgroup::'; }
