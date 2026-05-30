#!/usr/bin/env bash
# Unit tests for scripts/posts-publishing-today.sh
#
# Self-contained: each case builds an isolated posts dir and pins "today" via
# TODAY_OVERRIDE. No git, no network, no framework.
#
# Usage: bash scripts/test-posts-publishing-today.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/posts-publishing-today.sh"
TODAY="2026-05-29"

PASS=0
FAIL=0
pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; (( PASS += 1 )); }
fail() {
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
  printf "         expected: %s\n" "${2:-<empty>}"
  printf "         actual:   %s\n" "${3:-<empty>}"
  (( FAIL += 1 ))
}
assert_eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "$2" "$3"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

make_post() {
  # make_post <file> <publishDate> [draft=true|false]
  local file="$TMP/$1" pub="$2" draft="${3:-false}"
  {
    echo "---"
    echo 'title: "T"'
    echo "publishDate: ${pub}T00:00:00Z"
    [ "$draft" = "true" ] && echo "draft: true"
    echo "---"
    echo "body"
  } > "$file"
}

run() { POSTS_DIR="$TMP" TODAY_OVERRIDE="$TODAY" "$SCRIPT"; }

echo "── posts-publishing-today ──────────────────────────────"

# Today-dated, non-draft post is listed.
make_post due.md "$TODAY"
assert_eq "today-dated post is listed" "$TMP/due.md" "$(run)"

# Future-dated post is not listed.
rm -f "$TMP"/*.md
make_post future.md "2026-06-15"
assert_eq "future-dated post is excluded" "" "$(run)"

# Past-dated post is not listed (only *today* flips live today).
rm -f "$TMP"/*.md
make_post past.md "2026-05-01"
assert_eq "past-dated post is excluded" "" "$(run)"

# Today-dated but draft is excluded.
rm -f "$TMP"/*.md
make_post draft.md "$TODAY" true
assert_eq "today-dated draft is excluded" "" "$(run)"

# Mixed dir: only the today-dated non-draft survives.
rm -f "$TMP"/*.md
make_post due.md "$TODAY"
make_post future.md "2026-06-15"
make_post draft.md "$TODAY" true
assert_eq "mixed dir lists only today's non-draft" "$TMP/due.md" "$(run)"

# Empty dir is a clean no-op.
rm -f "$TMP"/*.md
assert_eq "empty dir yields nothing" "" "$(run)"

echo
echo "$((PASS + FAIL)) tests run — $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
