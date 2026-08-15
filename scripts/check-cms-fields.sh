#!/usr/bin/env bash
# Asserts that every frontmatter key present in CMS-managed content directories
# is declared as a field in static/admin/config.yml.
#
# Sveltia CMS only serializes fields it knows about. Any key not declared in the
# config is silently dropped the next time that entry is saved through the CMS.
# This guard runs in CI (via make test → lint.yml) and also locally before push.
#
# Usage:
#   bash scripts/check-cms-fields.sh
#
# Tunables (env):
#   CMS_CONFIG        path to config.yml (default: <repo>/static/admin/config.yml)
#   CMS_CONTENT_DIRS  colon-separated list of dirs to scan (default: <repo>/content/posts)
#
# Exits 0 when every key is declared; exits 1 and lists undeclared keys otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG="${CMS_CONFIG:-${REPO_ROOT}/static/admin/config.yml}"

# Default to posts only; PR4 will add content/talks and content/newsletter/the-unwind.
IFS=':' read -ra CONTENT_DIRS <<< "${CMS_CONTENT_DIRS:-${REPO_ROOT}/content/posts}"

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: CMS config not found: $CONFIG" >&2
  exit 1
fi

# Extract top-level field names declared in the config. Only two indents are
# top-level fields (collections > fields > field-item):
#
#       - name: promote          <- 6 spaces, list-dash form
#         name: title            <- 8 spaces, when `- label:` opens the item
#
# Shallower `name:` values are backend or collection identifiers. Deeper ones
# are nested object fields — `cover.alt` sits at 12 spaces. Matching those too
# would let a future top-level `alt` key pass the guard on the strength of
# `cover.alt` being declared, which is exactly the silent drop this exists to
# prevent.
declared() {
  grep -oE '^( {6}- | {8})name:[[:space:]]+[^[:space:]#]+' "$CONFIG" \
    | sed 's/.*name:[[:space:]]*//' \
    | sort -u
}

# Extract every frontmatter key present in content files. Reads between the
# first two `---` delimiters and matches top-level keys only.
content_keys() {
  local dir="$1"
  find "$dir" -maxdepth 1 -name '*.md' | while IFS= read -r f; do
    awk 'FNR==1{n=0} /^---[[:space:]]*$/{n++; next} n==1 && /^[a-zA-Z_][a-zA-Z_0-9]*:/{sub(/:.*/,""); print}' "$f"
  done | sort -u
}

DECLARED=$(declared)
FAIL=0

for dir in "${CONTENT_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    if ! echo "$DECLARED" | grep -qx "$key"; then
      echo "UNDECLARED: '$key' found in $(basename "$dir")/ but not in $CONFIG" >&2
      FAIL=1
    fi
  done < <(content_keys "$dir")
done

if [ "$FAIL" -eq 0 ]; then
  echo "OK: all frontmatter keys are declared in the CMS config."
else
  echo "" >&2
  echo "Add the missing key(s) as 'widget: hidden' fields in $CONFIG" >&2
  echo "to prevent Sveltia CMS from silently dropping them on save." >&2
  exit 1
fi
