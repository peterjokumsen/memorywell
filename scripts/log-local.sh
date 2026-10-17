# shellcheck shell=bash
# Local logging backend: colour when stdout is a TTY, plain text otherwise.
# Sourced by log.sh, never directly. See log-ghactions.sh for the GitHub
# Actions counterpart — both must define the same functions, which the `shell`
# job in .github/workflows/ci.yml checks.

# Colour helpers: auto-disabled when output is not a TTY or NO_COLOR is set,
# so piped/logged output stays plain. Use step/info/success/warn for stdout
# messaging; error goes to stderr. Never use these inside $(...) captures.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\e[0m'; C_BLUE=$'\e[34m'; C_GREEN=$'\e[32m'
  C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_CYAN=$'\e[36m'
else
  C_RESET=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''
fi

step()    { printf '%b==>%b %s\n' "$C_BLUE" "$C_RESET" "$*"; }
info()    { printf '%b%s%b\n' "$C_CYAN" "$*" "$C_RESET"; }
success() { printf '%b%s%b\n' "$C_GREEN" "$*" "$C_RESET"; }
warn()    { printf '%b%s%b\n' "$C_YELLOW" "$*" "$C_RESET"; }
error()   { printf '%b%s%b\n' "$C_RED" "$*" "$C_RESET" >&2; }
debug()   { printf '%b%s%b\n' "$C_CYAN" "debug: $*" "$C_RESET"; }

# group/endgroup bracket a noisy section (e.g. a retry loop). GitHub Actions
# collapses these; locally they are just banner lines, so a local log has the
# same shape as the CI one. Always pair them — an unbalanced endgroup swallows
# the rest of the step's output in CI.
group()    { printf '\n--- %s ---\n' "$*"; }
endgroup() { printf '%s\n' '---'; }
