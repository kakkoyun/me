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

# --- pretty-printed output ------------------------------------------------
#
# `hugo` without --minify splits a single tag across several lines. The checker
# buffers each file and scans it whole for exactly this reason; scanning line by
# line reported 531 of 540 images unsized against a dev build.

reset
write_page index.html '<img src="/a.png" alt="a"
    width="800" height="600">'
assert_rc "a tag split across lines is read whole" 0 "$(rc_of)"

reset
write_page index.html '<img
      src="/a.png"
      alt="a"
      loading="lazy"
      width="800"
      height="600">'
assert_rc "one attribute per line passes" 0 "$(rc_of)"

reset
write_page index.html '<img src="/a.png"
    alt="a"
    loading="lazy">'
assert_rc "a tag split across lines with no dimensions still fails" 1 "$(rc_of)"

reset
write_page a.html '<img src="/a.png" alt="a"
    width="8" height="6">'
write_page b.html '<img src="/b.png"
    alt="b">'
assert_rc "buffering does not leak between files" 1 "$(rc_of)"

reset
write_page a.html '<img src="/a.png" alt="a"
    width="8" height="6">'
write_page b.html '<img src="/b.png" alt="b"
    width="2" height="2">'
assert_rc "several files of split tags all pass" 0 "$(rc_of)"

# --- dimensions that are present but useless ------------------------------
#
# An attribute name is not a dimension. Each of these carries both width= and
# height= and still gives the browser no aspect ratio to reserve space with, so
# accepting them would let exactly the regression this check exists for through.

reset
write_page index.html '<img src="/a.png" alt="a" width="" height="">'
assert_rc "empty width and height fail" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" width="auto" height="auto">'
assert_rc "width=auto fails" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" width="abc" height="xyz">'
assert_rc "non-numeric dimensions fail" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" width="0" height="0">'
assert_rc "zero dimensions fail" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" width="800" height="">'
assert_rc "one good and one empty dimension fails" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" width="800.5" height="600.5">'
assert_rc "fractional dimensions fail" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" width=" 800 " height=" 600 ">'
assert_rc "dimensions with surrounding space still pass" 0 "$(rc_of)"

# --- style declarations that are present but useless ----------------------
#
# `width:` is a substring of `max-width:`, so a naive match accepted a purely
# relative style as though it were a concrete size.

reset
write_page index.html '<img src="/a.png" alt="a" style="max-width:100%;max-height:100%">'
assert_rc "max-width/max-height alone fail" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" style="width:auto;height:auto">'
assert_rc "style width:auto fails" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" style="min-width:10px;min-height:4px">'
assert_rc "min-width/min-height alone fail" 1 "$(rc_of)"

# The Buy Me A Coffee button in content/_index.md is the reason the CSS branch
# exists at all. It must keep passing whatever else gets tightened.
reset
write_page index.html '<a href="https://buymeacoffee.com/kakkoyun"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 32px; width: 114px;"></a>'
assert_rc "the real Buy Me A Coffee button still passes" 0 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" style="max-width:100%;width:10px;height:4px">'
assert_rc "a concrete size alongside max-width passes" 0 "$(rc_of)"

# --- case ------------------------------------------------------------------
#
# HTML element and attribute names are case-insensitive, and config.yaml sets
# goldmark unsafe: true, so raw HTML in content reaches the output verbatim.
# A case-sensitive scan was invisible to <IMG> entirely and, worse, rejected a
# perfectly well-formed tag that happened to use WIDTH/HEIGHT.

reset
write_page index.html '<IMG SRC="/a.png" ALT="a">'
assert_rc "uppercase IMG with no dimensions is still caught" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a" WIDTH="800" HEIGHT="600">'
assert_rc "uppercase WIDTH/HEIGHT attributes pass" 0 "$(rc_of)"

reset
write_page index.html '<Img Src="/a.png" Alt="a" Width="800" Height="600">'
assert_rc "mixed-case tag and attributes pass" 0 "$(rc_of)"

reset
write_page index.html '<IMG SRC="/a.png" STYLE="WIDTH: 10px; HEIGHT: 4px">'
assert_rc "uppercase style declarations pass" 0 "$(rc_of)"

reset
write_page index.html '<IMG SRC="/a.png" ALT="a" WIDTH="auto" HEIGHT="auto">'
assert_rc "uppercase attributes are still value-checked" 1 "$(rc_of)"

# --- CSS values that are not lengths ---------------------------------------
#
# A value merely starting with a digit is not a length: the browser drops the
# whole declaration and the image is unsized again.

reset
write_page index.html '<img src="/a.png" style="width:1bogus;height:2bogus">'
assert_rc "invalid CSS units fail" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" style="width:10;height:4">'
assert_rc "unitless non-zero CSS lengths fail" 1 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" style="width:10.5rem;height:4.25em">'
assert_rc "fractional CSS lengths with units pass" 0 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" style="width:50%;height:25%">'
assert_rc "percentage CSS lengths pass" 0 "$(rc_of)"

# --- tag boundaries --------------------------------------------------------

# Regressed once already: a split that consumes the character after "img"
# leaves the first attribute with no preceding whitespace, and the parser keys
# off exactly that.
reset
write_page index.html '<img width=800 height=600 src="/a.png" alt="a">'
assert_rc "dimensions as the first attribute are seen" 0 "$(rc_of)"

reset
write_page index.html '<img src="/a.png" alt="a">'
assert_rc "src as the first attribute is seen (allowlist depends on it)" 1 "$(rc_of)"

# <image> is a real SVG element and is not an <img>.
reset
write_page index.html '<svg><image href="/a.svg" x="0" y="0"/></svg>'
assert_rc "an SVG <image> element is not mistaken for an <img>" 0 "$(rc_of)"

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
