# shellcheck shell=bash
# Bruno environment editing shared by the publish scripts. Sourced, never run.
# Kept separate from common.sh so the rewrite logic has one definition: both
# publish-containers.sh and publish-functions.sh point a variable at a deployed
# hostname, and a drift between two copies would silently leave Bruno stale.

# bruno_set_var <file> <var> <value>
# Rewrites the `value:` directly under `- name: <var>` without touching any
# other variable (or needing yq on the machine). Returns 1 when the variable is
# not defined in the file, so the caller can warn instead of pretending success.
bruno_set_var() {
  local file="$1"
  local var="$2"
  local value="$3"
  local tmp

  if ! grep -q "name: ${var}$" "$file"; then
    return 1
  fi

  tmp="$(mktemp)"
  awk -v var="$var" -v value="$value" '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      name = $0
      sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", name)
      in_var = (name == var)
    }
    in_var && /^[[:space:]]*value:/ {
      match($0, /^[[:space:]]*/)
      indent = substr($0, 1, RLENGTH)
      print indent "value: " value
      in_var = 0
      next
    }
    { print }
  ' "$file" > "$tmp"
  # Copy back rather than mv: mktemp creates 0600, and mv would replace the
  # tracked file's permissions with those.
  cat "$tmp" > "$file"
  rm -f "$tmp"
}
