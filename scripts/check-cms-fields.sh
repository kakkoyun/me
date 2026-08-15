#!/usr/bin/env bash
# Asserts that every frontmatter key present in CMS-managed content directories
# is declared as a field of the collection that owns that directory.
#
# Sveltia CMS only serializes fields it knows about. Any key not declared in the
# collection is silently dropped the next time that entry is saved through the
# CMS. This guard runs in CI (via make test → lint.yml) and also locally.
#
# The check is per-collection, not global. `series` being declared on posts says
# nothing about a talk, and Sveltia will drop it from a talk regardless.
#
# Usage:
#   bash scripts/check-cms-fields.sh
#
# Tunables (env):
#   CMS_CONFIG       path to config.yml (default: <repo>/static/admin/config.yml)
#   CMS_CONTENT_ROOT directory the collections' `folder:` paths resolve against
#                    (default: <repo>)
#
# The set of scanned directories is not configurable: it is every `folder:` in
# the config, which is by definition every directory the CMS can write to.
#
# Exits 0 when every key is declared; exits 1 and lists undeclared keys otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG="${CMS_CONFIG:-${REPO_ROOT}/static/admin/config.yml}"
CONTENT_ROOT="${CMS_CONTENT_ROOT:-${REPO_ROOT}}"

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: CMS config not found: $CONFIG" >&2
  exit 1
fi

# Emit one line per folder collection: "<folder>\t<field> <field> ...".
#
# Only two indents hold top-level field names (collections > fields > item):
#
#       - name: promote          <- 6 spaces, list-dash form
#         name: title            <- 8 spaces, when `- label:` opens the item
#
# Shallower `name:` values are backend or collection identifiers. Deeper ones
# are nested object fields — `cover.alt` sits at 12 spaces. Matching those too
# would let a future top-level `alt` key pass on the strength of `cover.alt`
# being declared, which is exactly the silent drop this exists to prevent.
collections() {
  awk '
    /^  - name:[[:space:]]/ { col++; folder[col] = ""; next }
    col && /^    folder:[[:space:]]/ {
      f = $0
      sub(/^    folder:[[:space:]]*/, "", f)
      sub(/[[:space:]]*$/, "", f)
      folder[col] = f
      next
    }
    col && /^( {6}- |        )name:[[:space:]]/ {
      n = $0
      sub(/^.*name:[[:space:]]*/, "", n)
      sub(/[[:space:]].*$/, "", n)
      fields[col] = fields[col] " " n
    }
    END {
      for (i = 1; i <= col; i++)
        if (folder[i] != "") print folder[i] "\t" fields[i]
    }
  ' "$CONFIG"
}

# Extract every frontmatter key present in content files. Reads between the
# first two `---` delimiters and matches top-level keys only.
#
# `_index.md` is skipped: Hugo section pages are hidden from a folder collection
# unless it sets `index_file`, and none do. They carry keys (`comments: false`)
# that the CMS never sees and therefore cannot drop. Revisit if a collection
# ever sets `index_file`.
content_keys() {
  local dir="$1"
  find "$dir" -maxdepth 1 -name '*.md' ! -name '_index.md' | while IFS= read -r f; do
    awk 'FNR==1{n=0} /^---[[:space:]]*$/{n++; next} n==1 && /^[a-zA-Z_][a-zA-Z_0-9]*:/{sub(/:.*/,""); print}' "$f"
  done | sort -u
}

FAIL=0
SCANNED=0

while IFS=$'\t' read -r folder fields; do
  dir="${CONTENT_ROOT}/${folder}"
  [ -d "$dir" ] || continue
  SCANNED=$((SCANNED + 1))
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    # Space-delimited membership test; $fields is " a b c" with a leading space.
    case " ${fields# } " in
      *" $key "*) ;;
      *)
        echo "UNDECLARED: '$key' found in ${folder}/ but not declared on that collection in $CONFIG" >&2
        FAIL=1
        ;;
    esac
  done < <(content_keys "$dir")
done < <(collections)

if [ "$SCANNED" -eq 0 ]; then
  echo "ERROR: no collection folder in $CONFIG resolved to a directory under $CONTENT_ROOT" >&2
  exit 1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "OK: all frontmatter keys are declared on their own collection."
else
  echo "" >&2
  echo "Add the missing key(s) as 'widget: hidden' fields to that collection in" >&2
  echo "$CONFIG to prevent Sveltia CMS from silently dropping them on save." >&2
  exit 1
fi
