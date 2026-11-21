#!/usr/bin/env bash
# Unit tests for scripts/check-ai-provenance.sh
#
# Self-contained and offline: each case builds an isolated tree of fixture files
# and points the checker at it. No network, no c2patool, no framework.
#
# The image fixtures are synthetic rather than real generated images, which is
# the right call and not a shortcut: the checker's contract is a byte scan for
# C2PA marker strings, so a fixture that contains those bytes exercises exactly
# the code path a real signed JPEG would. Committing a genuinely AI-generated
# image to prove the point would also mean committing an AI-generated image.
#
# The cases that matter most are the negative ones — a photographer named
# Claude, an algorithmicallyEnhanced denoise, a filename that says midjourney.
# A checker that blocks merges has to be right about what it lets through, or it
# gets switched off.
#
# Usage: bash scripts/test-check-ai-provenance.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-ai-provenance.sh"

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
  rm -rf "${TMP:?}/static" "${TMP:?}/content"
  mkdir -p "$TMP/static/uploads" "$TMP/content/posts"
  : >"$TMP/allowlist.txt"
}

# A C2PA manifest store, near enough. Both JUMBF markers the checker requires,
# plus whatever assertion strings the case is about.
write_signed_image() { # <name> <assertion-strings...>
  local file="$TMP/static/uploads/$1"
  shift
  {
    printf '\xff\xd8\xff\xe0JFIF'
    printf 'jumb\x00jumd'
    printf 'c2pa'
    local s
    for s in "$@"; do printf '\x00%s' "$s"; done
    printf '\x00\xff\xd9'
  } >"$file"
}

# No manifest at all: an ordinary photo.
write_plain_image() { # <name> <trailing-text>
  printf '\xff\xd8\xff\xe0JFIF%s\xff\xd9' "${2:-}" >"$TMP/static/uploads/$1"
}

write_post() { # <name> <frontmatter-body>
  printf -- '---\n%s\n---\n\nBody text.\n' "$2" >"$TMP/content/posts/$1"
}

# C2PATOOL_CMD is pointed at a name that cannot resolve, so the byte-scan path
# is what runs. Otherwise a machine that happens to have c2patool installed
# would silently test a different branch than CI does.
rc_of() {
  set +e
  env -u WATERMARK_DETECT_CMD \
    AI_PROV_ROOT="$TMP" \
    AI_PROV_SCAN_DIRS=static \
    AI_PROV_TEXT_DIRS=content \
    AI_PROV_ALLOWLIST="$TMP/allowlist.txt" \
    C2PATOOL_CMD=__no_such_c2patool__ \
    bash "$SCRIPT" >/dev/null 2>&1
  local r=$?
  set -e
  echo "$r"
}

echo "check-ai-provenance.sh"

# --- images that must pass ------------------------------------------------

reset
assert_rc "a tree with no images passes" 0 "$(rc_of)"

reset
write_plain_image clean.jpeg
assert_rc "an unsigned photo passes" 0 "$(rc_of)"

reset
write_signed_image camera.jpeg \
  'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture' 'Leica M11'
assert_rc "a signed camera capture passes" 0 "$(rc_of)"

reset
write_signed_image denoised.jpeg \
  'http://cv.iptc.org/newscodes/digitalsourcetype/algorithmicallyEnhanced' \
  'Adobe Photoshop 26.0'
assert_rc "algorithmicallyEnhanced is not AI generation" 0 "$(rc_of)"

reset
write_signed_image credit.jpeg \
  'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture' \
  'photographer: Claude Dubois'
assert_rc "a photo credited to a person named Claude passes" 0 "$(rc_of)"

reset
write_plain_image midjourney-talk-slide.png
assert_rc "an unsigned file whose NAME says midjourney passes" 0 "$(rc_of)"

reset
write_plain_image screenshot.png 'I generated this with DALL-E, said the post'
assert_rc "generator names in an unsigned file's bytes pass" 0 "$(rc_of)"

# --- images that must fail ------------------------------------------------

reset
write_signed_image generated.png \
  'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia'
assert_rc "trainedAlgorithmicMedia fails" 1 "$(rc_of)"

reset
write_signed_image composite.png \
  'http://cv.iptc.org/newscodes/digitalsourcetype/compositeWithTrainedAlgorithmicMedia'
assert_rc "compositeWithTrainedAlgorithmicMedia fails" 1 "$(rc_of)"

reset
write_signed_image algo.png \
  'http://cv.iptc.org/newscodes/digitalsourcetype/algorithmicMedia'
assert_rc "algorithmicMedia fails" 1 "$(rc_of)"

reset
write_signed_image tool.png 'claim_generator' 'Midjourney v7'
assert_rc "a known generative tool in a signed image fails" 1 "$(rc_of)"

reset
write_signed_image firefly.png 'claim_generator_info' 'Adobe Firefly'
assert_rc "Adobe Firefly in a signed image fails" 1 "$(rc_of)"

# --- the allowlist --------------------------------------------------------

reset
write_signed_image wanted.png \
  'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia'
printf '%s\n' '^static/uploads/wanted\.png$' >"$TMP/allowlist.txt"
assert_rc "an allowlisted AI image passes" 0 "$(rc_of)"

reset
write_signed_image other.png \
  'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia'
printf '%s\n' '# just a comment' '' '^static/uploads/wanted\.png$' >"$TMP/allowlist.txt"
assert_rc "comments and blanks in the allowlist do not match everything" 1 "$(rc_of)"

# The committed allowlist is entirely comments, so a run that reads it must not
# mistake "no patterns" for a failure. `[ -n "$line" ] && arr+=(…)` as the last
# statement in the read loop returned 1 on the final blank line and set -e took
# the whole script down — silently, with exit 1 and no output.
reset
write_plain_image clean.jpeg
printf '%s\n' '# only comments here' '#' '' >"$TMP/allowlist.txt"
assert_rc "an all-comments allowlist does not fail the run" 0 "$(rc_of)"

# --- c2patool, when it is available ---------------------------------------
#
# The stub reports a generated asset for a file carrying none of the marker
# bytes, so a pass here can only come from the c2patool branch being taken.

reset
write_plain_image via-tool.png
cat >"$TMP/c2patool" <<'STUB'
#!/usr/bin/env bash
echo '{"digitalSourceType":"http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia"}'
STUB
chmod +x "$TMP/c2patool"
set +e
env -u WATERMARK_DETECT_CMD AI_PROV_ROOT="$TMP" \
  AI_PROV_SCAN_DIRS=static AI_PROV_TEXT_DIRS=content \
  AI_PROV_ALLOWLIST="$TMP/allowlist.txt" C2PATOOL_CMD="$TMP/c2patool" \
  bash "$SCRIPT" >/dev/null 2>&1
TOOL_RC=$?
set -e
assert_rc "c2patool's verdict is used when it is available" 1 "$TOOL_RC"

# --- the text watermark seam ----------------------------------------------

reset
write_post post.md 'title: "A Post"'
assert_rc "no WATERMARK_DETECT_CMD skips the text check" 0 "$(rc_of)"

# Detector contract: exit 0 clean, 10 watermarked, anything else is an error.
printf '#!/usr/bin/env bash\nexit 10\n' >"$TMP/detect-hit"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/detect-clean"
printf '#!/usr/bin/env bash\nexit 3\n' >"$TMP/detect-broken"
chmod +x "$TMP/detect-hit" "$TMP/detect-clean" "$TMP/detect-broken"

rc_with_detector() { # <detector> — set after env -u strips the inherited one
  set +e
  env -u WATERMARK_DETECT_CMD \
    AI_PROV_ROOT="$TMP" \
    AI_PROV_SCAN_DIRS=static AI_PROV_TEXT_DIRS=content \
    AI_PROV_ALLOWLIST="$TMP/allowlist.txt" C2PATOOL_CMD=__no_such_c2patool__ \
    WATERMARK_DETECT_CMD="$1" \
    bash "$SCRIPT" >/dev/null 2>&1
  local r=$?
  set -e
  echo "$r"
}

reset
write_post post.md 'title: "A Post"'
assert_rc "a clean detector passes" 0 "$(rc_with_detector "$TMP/detect-clean")"

reset
write_post post.md 'title: "A Post"'
assert_rc "an undisclosed watermark hit fails" 1 "$(rc_with_detector "$TMP/detect-hit")"

reset
write_post post.md 'title: "A Post"
aiAssisted:
  - draft'
assert_rc "a watermark hit disclosed via aiAssisted passes" 0 \
  "$(rc_with_detector "$TMP/detect-hit")"

reset
write_post post.md 'title: "A Post"
draft: true'
assert_rc "a draft is not gated" 0 "$(rc_with_detector "$TMP/detect-hit")"

reset
write_post post.md 'title: "A Post"'
assert_rc "a detector that errors fails the check" 1 \
  "$(rc_with_detector "$TMP/detect-broken")"

# A nested `aiAssisted:` under some other key must not count as disclosure —
# fm_has anchors to column 0 precisely so this stays a failure.
reset
write_post post.md 'title: "A Post"
cover:
  aiAssisted: true'
assert_rc "a nested aiAssisted is not disclosure" 1 "$(rc_with_detector "$TMP/detect-hit")"

# --- summary --------------------------------------------------------------

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
