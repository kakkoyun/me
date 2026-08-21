#!/usr/bin/env bash
# Unit tests for scripts/record-promotion.sh
#
# Self-contained and offline: each case builds an isolated post in a temp dir.
# No git, no network, no framework.
#
# The emphasis is on what this tool must never do. It rewrites real published
# posts unattended in CI, so "appends the right timestamp" is the easy half —
# the cases that matter are the ones proving it leaves everything else alone,
# and that a rejected edit leaves the file exactly as it was.
#
# Usage: bash scripts/test-record-promotion.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/record-promotion.sh"
# shellcheck source=scripts/lib/frontmatter.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/frontmatter.sh"

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

STAMP="2026-08-21T06:03:00Z"

make_post() {
  # make_post <file> [extra frontmatter line]
  local file="$TMP/$1"
  {
    echo "---"
    echo "title: \"Test Post\""
    echo "publishDate: 2026-08-21T00:00:00Z"
    echo "tags:"
    echo "  - blog"
    [ -n "${2:-}" ] && echo "$2"
    echo "---"
    echo ""
    echo "Body paragraph."
  } > "$file"
}

run() { printf '%s\n' "$1" | bash "$SCRIPT" --at "$STAMP" 2>/dev/null; }

echo "── record-promotion ────────────────────────────────────"

# Creates the key when absent.
make_post a.md
run "$TMP/a.md" >/dev/null
assert_eq "creates promotedAt when absent" "$STAMP" "$(fm_list "$TMP/a.md" promotedAt)"

# Appends rather than replacing.
printf '%s\n' "$TMP/a.md" | bash "$SCRIPT" --at "2026-09-04T06:02:00Z" >/dev/null 2>&1
assert_eq "appends a second entry" "$STAMP
2026-09-04T06:02:00Z" "$(fm_list "$TMP/a.md" promotedAt)"

# The key must be declared exactly once, no matter how many appends.
assert_eq "never declares promotedAt twice" "1" \
  "$(fm_block "$TMP/a.md" | grep -c '^promotedAt:')"

# Other frontmatter survives untouched.
assert_eq "leaves other frontmatter keys intact" "blog" "$(fm_list "$TMP/a.md" tags)"
assert_eq "leaves publishDate intact" "2026-08-21T00:00:00Z" "$(fm_get "$TMP/a.md" publishDate)"

# Appending into a list that is the last key before the closing delimiter.
make_post b.md
run "$TMP/b.md" >/dev/null
printf '%s\n' "$TMP/b.md" | bash "$SCRIPT" --at "2026-09-04T06:02:00Z" >/dev/null 2>&1
assert_eq "appends correctly when promotedAt is the final key" "2" \
  "$(fm_list "$TMP/b.md" promotedAt | wc -l | tr -d ' ')"

# Body bytes are preserved, including a markdown horizontal rule that looks
# exactly like a frontmatter delimiter.
{
  echo "---"
  echo "title: \"HR\""
  echo "publishDate: 2026-08-21T00:00:00Z"
  echo "---"
  echo ""
  echo "Intro."
  echo ""
  echo "---"
  echo ""
  echo "After the rule."
} > "$TMP/hr.md"
cp "$TMP/hr.md" "$TMP/hr.orig"
run "$TMP/hr.md" >/dev/null
assert_eq "preserves a body containing a --- horizontal rule" \
  "$(tail -n +5 "$TMP/hr.orig")" "$(tail -n +7 "$TMP/hr.md")"

# A file with no trailing newline must come back with no trailing newline.
# awk terminates every record, so this is a real regression risk: an earlier
# version silently rewrote the last line of two published posts.
printf -- '---\ntitle: "NoNewline"\npublishDate: 2026-08-21T00:00:00Z\n---\n\nEnds without a newline.' > "$TMP/nn.md"
run "$TMP/nn.md" >/dev/null
# $( ) strips a trailing newline, so a non-empty result here means the last
# byte is NOT a newline — which is what we want preserved.
assert_eq "does not add a trailing newline to a file that lacked one" "." \
  "$(tail -c1 "$TMP/nn.md")"
assert_eq "still stamped the no-trailing-newline file" "$STAMP" \
  "$(fm_list "$TMP/nn.md" promotedAt)"

# ── failure paths: the file must be left exactly as it was ────────────────────

echo "hello, no frontmatter" > "$TMP/bad.md"
cp "$TMP/bad.md" "$TMP/bad.orig"
set +e
printf '%s\n' "$TMP/bad.md" | bash "$SCRIPT" --at "$STAMP" >/dev/null 2>&1
rc=$?
set -e
assert_eq "exits non-zero on a file with no frontmatter" "1" "$rc"
assert_eq "leaves a rejected file byte-identical" \
  "$(cat "$TMP/bad.orig")" "$(cat "$TMP/bad.md")"

set +e
printf '%s\n' "$TMP/missing.md" | bash "$SCRIPT" --at "$STAMP" >/dev/null 2>&1
rc=$?
set -e
assert_eq "exits non-zero on a missing file" "1" "$rc"

set +e
printf '%s\n' "$TMP/a.md" | bash "$SCRIPT" --at "2026-08-21" >/dev/null 2>&1
rc=$?
set -e
assert_eq "rejects a malformed --at timestamp" "1" "$rc"

# A bad path in the batch must not stop the good ones.
make_post good.md
set +e
printf '%s\n%s\n' "$TMP/missing.md" "$TMP/good.md" | bash "$SCRIPT" --at "$STAMP" >/dev/null 2>&1
rc=$?
set -e
assert_eq "still stamps valid posts when another path in the batch fails" "$STAMP" \
  "$(fm_list "$TMP/good.md" promotedAt)"
assert_eq "but reports failure for the batch" "1" "$rc"

# Echoes stamped paths for the caller to consume.
make_post echoed.md
assert_eq "echoes each stamped path on stdout" "$TMP/echoed.md" "$(run "$TMP/echoed.md")"

echo ""
TOTAL=$(( PASS + FAIL ))
printf "%d/%d tests passed\n" "$PASS" "$TOTAL"
[ "$FAIL" -eq 0 ]
