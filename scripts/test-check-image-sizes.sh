#!/usr/bin/env bash
# Unit tests for scripts/check-image-sizes.sh
#
# Self-contained and offline: each case builds an isolated public dir of fake
# HTML and points the checker at it. No Hugo, no network, no framework.
#
# The cases that matter most are the minified ones. Hugo ships the site with
# --minify, so attribute values arrive unquoted and a whole page is one very
# long line — a checker that only understands pretty-printed HTML would pass
# everything and catch nothing.
#
# Usage: bash scripts/test-check-image-sizes.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-image-sizes.sh"

PASS=0
FAIL=0
pass() {
  printf "  \033[32mPASS\033[0m  %s\n" "$1"
  ((PASS += 1))
}
fail() {
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
  printf "         expected exit: %s\n" "$2"
  printf "         actual exit:   %s\n" "$3"
  ((FAIL += 1))
}
assert_rc() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "$2" "$3"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

reset() {
  rm -rf "${TMP:?}/public"
  mkdir -p "$TMP/public"
  rm -f "$TMP/allowlist.txt"
}

# write_page <name> <html...>
write_page() {
  local file="$TMP/public/$1"
  shift
  mkdir -p "$(dirname "$file")"
  printf '%s' "$@" >"$file"
}

rc_of() {
  set +e
  IMAGE_SIZE_ALLOWLIST="$TMP/allowlist.txt" bash "$SCRIPT" "$TMP/public" >/dev/null 2>&1
  local r=$?
  set -e
  echo "$r"
}

echo "check-image-sizes.sh"

# --- the passing shapes ---------------------------------------------------

reset
write_page index.html '<html><body><img src="/a.png" alt="a" width="800" height="600"></body></html>'
assert_rc "quoted width and height pass" 0 "$(rc_of)"

reset
write_page index.html '<html><body><img src=/a.png alt=a width=800 height=600></body></html>'
assert_rc "minified unquoted width and height pass" 0 "$(rc_of)"

reset
write_page index.html "<html><body><img src='/a.png' alt='a' width='800' height='600'></body></html>"
assert_rc "single-quoted width and height pass" 0 "$(rc_of)"

reset
write_page index.html '<html><body><img src=/a.png alt=a style=height:32px;width:114px></body></html>'
assert_rc "inline style with width and height passes" 0 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" style="width: 10px; height: 4px">'
assert_rc "inline style with spaces passes" 0 "$(rc_of)"

reset
write_page index.html '<img src=/a.png alt=a width=800 height=600/>'
assert_rc "self-closing tag passes" 0 "$(rc_of)"

reset
mkdir -p "$TMP/public"
write_page index.html '<html><body><p>No images here at all.</p></body></html>'
assert_rc "a build with no images passes" 0 "$(rc_of)"

# --- the failing shapes ---------------------------------------------------

reset
write_page index.html '<html><body><img src="/a.png" alt="a"></body></html>'
assert_rc "no dimensions fails" 1 "$(rc_of)"

reset
write_page index.html '<html><body><img src="/a.png" alt="a" width="800"></body></html>'
assert_rc "width without height fails" 1 "$(rc_of)"

reset
write_page index.html '<html><body><img src="/a.png" alt="a" height="600"></body></html>'
assert_rc "height without width fails" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" style="width: 10px">'
assert_rc "inline style with only width fails" 1 "$(rc_of)"

# A srcset carries "w" descriptors that look like widths but give the browser
# no intrinsic size. Guard against a checker that mistakes one for the other.
reset
write_page index.html '<img src=/a.png srcset="/a-480.png 480w, /a-960.png 960w" sizes=100vw alt=a>'
assert_rc "srcset w-descriptors alone fail" 1 "$(rc_of)"

# --- the minified realities -----------------------------------------------

reset
write_page index.html '<img src=/a.png alt=a width=8 height=6><img src=/b.png alt=b><img src=/c.png alt=c width=1 height=1>'
assert_rc "one unsized image among sized ones on a single line fails" 1 "$(rc_of)"

reset
write_page index.html '<img src=/a.png alt=a width=8 height=6><img src=/b.png alt=b width=2 height=2>'
assert_rc "several sized images on a single line pass" 0 "$(rc_of)"

reset
write_page nested/deep/index.html '<img src="/a.png" alt="a">'
assert_rc "unsized image in a nested directory fails" 1 "$(rc_of)"

# --- the allowlist --------------------------------------------------------

reset
write_page index.html '<html><body><img src="https://example.com/live.svg" alt="a"></body></html>'
printf '# a live badge whose size is not knowable at build time\n^https://example\\.com/live\\.svg$\n' >"$TMP/allowlist.txt"
assert_rc "an allowlisted src passes" 0 "$(rc_of)"

reset
write_page index.html '<html><body><img src="https://example.com/other.svg" alt="a"></body></html>'
printf '^https://example\\.com/live\\.svg$\n' >"$TMP/allowlist.txt"
assert_rc "a non-matching allowlist entry does not rescue an unsized image" 1 "$(rc_of)"

reset
write_page index.html '<html><body><img src="https://example.com/live.svg" alt="a"></body></html>'
printf '\n   \n# only comments and blanks\n' >"$TMP/allowlist.txt"
assert_rc "comments and blank lines in the allowlist are ignored" 1 "$(rc_of)"

# --- operational failure modes -------------------------------------------

reset
set +e
IMAGE_SIZE_ALLOWLIST="$TMP/allowlist.txt" bash "$SCRIPT" "$TMP/does-not-exist" >/dev/null 2>&1
rc=$?
set -e
assert_rc "a missing build directory is an error, not a pass" 1 "$rc"

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
