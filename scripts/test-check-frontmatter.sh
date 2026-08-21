#!/usr/bin/env bash
# Unit tests for scripts/check-frontmatter.sh
#
# Self-contained and offline: each case builds an isolated posts dir and points
# the checker at it via POSTS_DIR. No git, no network, no framework.
#
# Usage: bash scripts/test-check-frontmatter.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-frontmatter.sh"

PASS=0
FAIL=0
pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; (( PASS += 1 )); }
fail() {
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
  printf "         expected exit: %s\n" "$2"
  printf "         actual exit:   %s\n" "$3"
  (( FAIL += 1 ))
}
assert_rc() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "$2" "$3"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

reset() { rm -rf "${TMP:?}/posts"; mkdir -p "$TMP/posts"; }

# write_post <file> <body-of-frontmatter...>
write_post() {
  local file="$TMP/posts/$1"; shift
  {
    echo "---"
    printf '%s\n' "$@"
    echo "---"
    echo ""
    echo "Body."
  } > "$file"
}

run() { POSTS_DIR="$TMP/posts" bash "$SCRIPT" >/dev/null 2>&1; }
rc_of() { set +e; run; local r=$?; set -e; echo "$r"; }

VALID=('title: "T"' 'date: 2026-08-21T00:00:00Z' 'publishDate: 2026-08-21T00:00:00Z')

echo "── check-frontmatter ───────────────────────────────────"

reset; write_post ok.md "${VALID[@]}"
assert_rc "accepts a well-formed post" "0" "$(rc_of)"

reset; write_post nopub.md 'title: "T"' 'date: 2026-08-21T00:00:00Z'
assert_rc "rejects a post with no publishDate" "1" "$(rc_of)"

reset; write_post nodate.md 'title: "T"' 'publishDate: 2026-08-21T00:00:00Z'
assert_rc "rejects a post with no date" "1" "$(rc_of)"

reset; write_post baddate.md 'title: "T"' 'date: 2026-08-21T00:00:00Z' 'publishDate: August 21 2026'
assert_rc "rejects an unparseable publishDate" "1" "$(rc_of)"

reset; write_post dateonly.md 'title: "T"' 'date: 2026-08-21' 'publishDate: 2026-08-21'
assert_rc "accepts a bare YYYY-MM-DD publishDate" "0" "$(rc_of)"

reset; echo "no frontmatter here" > "$TMP/posts/raw.md"
assert_rc "rejects a file with no frontmatter block" "1" "$(rc_of)"

# _index.md is a Hugo section page, not a post — it carries none of these fields.
reset; write_post ok.md "${VALID[@]}"; echo "---" > "$TMP/posts/_index.md"
assert_rc "ignores _index.md" "0" "$(rc_of)"

# ── promotedAt shape ─────────────────────────────────────────────────────────

reset; write_post p.md "${VALID[@]}" 'promotedAt:' '  - 2026-08-21T06:03:00Z'
assert_rc "accepts a valid promotedAt list" "0" "$(rc_of)"

reset; write_post p.md "${VALID[@]}" 'promotedAt:' '  - 2026-08-21T06:03:00Z' '  - 2026-09-04T06:02:00Z'
assert_rc "accepts multiple promotedAt entries" "0" "$(rc_of)"

reset; write_post p.md "${VALID[@]}" 'promotedAt:' '  - 2026-08-21'
assert_rc "rejects a promotedAt entry without a time component" "1" "$(rc_of)"

reset; write_post p.md "${VALID[@]}" 'promotedAt:'
assert_rc "rejects a declared but empty promotedAt" "1" "$(rc_of)"

# An inline flow list parses as an empty block list, which would read as
# "never promoted" and cause a duplicate promotion. It must not pass silently.
reset; write_post p.md "${VALID[@]}" 'promotedAt: [2026-08-21T06:03:00Z]'
assert_rc "rejects an inline promotedAt list" "1" "$(rc_of)"

# ── directory-level guards ───────────────────────────────────────────────────

reset
assert_rc "fails when the posts directory is empty" "1" "$(rc_of)"

set +e
POSTS_DIR="$TMP/nonexistent" bash "$SCRIPT" >/dev/null 2>&1
rc=$?
set -e
assert_rc "fails when the posts directory does not exist" "1" "$rc"

# One bad post among good ones must fail the whole run.
reset
write_post good.md "${VALID[@]}"
write_post bad.md 'title: "T"' 'date: 2026-08-21T00:00:00Z'
assert_rc "one invalid post fails the run" "1" "$(rc_of)"

echo ""
TOTAL=$(( PASS + FAIL ))
printf "%d/%d tests passed\n" "$PASS" "$TOTAL"
[ "$FAIL" -eq 0 ]
