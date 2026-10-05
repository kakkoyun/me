#!/usr/bin/env bash
# Block undisclosed AI-generated content from reaching the site.
#
# Two independent checks, because AI provenance leaves two very different kinds
# of trace and only one of them is readable without a vendor's cooperation:
#
#   Images — C2PA Content Credentials. Claude, DALL·E, Imagen, Firefly and
#            friends sign generated images with a cryptographic manifest that
#            records an IPTC digitalSourceType of trainedAlgorithmicMedia. That
#            is a hard, offline, key-free signal, and it is what this script
#            actually enforces today.
#
#   Text   — a statistical watermark, detectable ONLY by the vendor that holds
#            the generating key. There is no offline check and no third-party
#            tool, at any price, that reads Claude's text watermark: Anthropic's
#            detection API is in private preview, scoped to EU-mandated
#            regulators and compliance-obligated enterprises. So this script
#            does not pretend to detect it. It delegates to a command you
#            supply (WATERMARK_DETECT_CMD) and skips cleanly when you have not.
#
# Deliberately NOT wired in: heuristic "AI detectors" (GPTZero, Originality,
# Pangram). Their false-positive rates are respectable now, but the same
# research shows ~13% of AI text slips past them once it imitates a specific
# author's voice — which is exactly what .claude/skills/kemal-voice/SKILL.md is
# for. A paid merge gate that misses this repo's actual risk case is friction
# without cover. See docs/ai-provenance.md for the full reasoning.
#
# Why source files and not the built site: Hugo's image processing
# (layouts/partials/functions/responsive-image.html resizes everything into a
# WebP srcset) strips metadata, so a C2PA manifest present in static/uploads/
# leaves no trace in public/. Scanning the build output would pass everything
# and catch nothing. This runs on what is committed.
#
# Usage:
#   bash scripts/check-ai-provenance.sh
#
# Tunables (env):
#   AI_PROV_ROOT        directory the two *_DIRS lists resolve against, and the
#                       prefix stripped from reported paths (default: <repo>)
#   AI_PROV_SCAN_DIRS   space-separated dirs to scan for images
#                       (default: "static assets content")
#   AI_PROV_TEXT_DIRS   space-separated dirs whose .md files are text-checked
#                       (default: "content")
#   AI_PROV_ALLOWLIST   file of extended regexes matched against an image path;
#                       blank lines and #-comments ignored
#                       (default: <repo>/scripts/ai-provenance-allowlist.txt)
#   WATERMARK_DETECT_CMD  text-watermark detector, called as: CMD <file>
#                         exit 0 = no watermark, 10 = watermark found,
#                         anything else = detector error (fails the check).
#                         Unset (the default) skips the text check entirely.
#   C2PATOOL_CMD        override the c2patool binary used for the authoritative
#                       manifest read (default: c2patool, if on PATH)
#   AI_PROV_MAX_REPORT  how many offenders to list before summarising
#                       (default: 25)
#
# Exits 0 when nothing undisclosed is found; exits 1 and names the offenders
# otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/frontmatter.sh
source "${SCRIPT_DIR}/lib/frontmatter.sh"

AI_PROV_ROOT="${AI_PROV_ROOT:-$REPO_ROOT}"
AI_PROV_SCAN_DIRS="${AI_PROV_SCAN_DIRS:-static assets content}"
AI_PROV_TEXT_DIRS="${AI_PROV_TEXT_DIRS:-content}"
AI_PROV_ALLOWLIST="${AI_PROV_ALLOWLIST:-${REPO_ROOT}/scripts/ai-provenance-allowlist.txt}"
AI_PROV_MAX_REPORT="${AI_PROV_MAX_REPORT:-25}"
C2PATOOL_CMD="${C2PATOOL_CMD:-c2patool}"
: "${WATERMARK_DETECT_CMD:=}"

# ── Allowlist ─────────────────────────────────────────────────────────────────

ALLOW_PATTERNS=()
load_allowlist() {
  [ -f "$AI_PROV_ALLOWLIST" ] || return 0
  local line
  while IFS= read -r line; do
    line="${line%%#*}"
    # Trim surrounding whitespace; a bare comment line collapses to empty.
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [ -n "$line" ]; then ALLOW_PATTERNS+=("$line"); fi
  done <"$AI_PROV_ALLOWLIST"
}

is_allowed() { # <path>
  local p="$1" re
  for re in ${ALLOW_PATTERNS+"${ALLOW_PATTERNS[@]}"}; do
    if printf '%s' "$p" | grep -qE "$re"; then return 0; fi
  done
  return 1
}

# ── C2PA manifest reading ─────────────────────────────────────────────────────
#
# A C2PA manifest is CBOR inside a JUMBF box tree: an APP11 segment in JPEG, a
# caBX chunk in PNG, a RIFF chunk in WebP. CBOR stores text strings verbatim
# rather than compressed, so the assertion values we care about are present in
# the file as literal, greppable bytes — which is why a byte scan is sound here
# and does not need a CBOR parser. It is container-agnostic for free.
#
# c2patool is strictly better when available (it validates the signature chain
# and resolves the manifest we would otherwise only pattern-match), so use it
# when it happens to be installed. It is not pinned in tools.mk on purpose: the
# byte scan is the contract, and requiring a Rust binary to run `make test`
# would buy accuracy this check does not depend on.

# The IPTC digitalSourceType vocabulary marks machine-generated media with
# three values, all of which end in "algorithmicMedia":
#
#   algorithmicMedia                       purely machine-generated
#   trainedAlgorithmicMedia                generated by a trained model
#   compositeWithTrainedAlgorithmicMedia   composite including model output
#
# One case-insensitive pattern therefore covers all three. Deliberately NOT
# matched: algorithmicallyEnhanced, which is denoise/upscale on a real capture
# and says nothing about AI authorship.
AI_SOURCE_TYPE_RE='algorithmicmedia'

# Generative tools that sign their output, for the case where a manifest names
# the generator but carries no digitalSourceType assertion. Kept narrow and
# explicit: a general-purpose editor in a provenance chain (Photoshop, Capture
# One, Lightroom) says nothing about how the pixels originated, so listing one
# here would flag every retouched conference photo.
#
# "claude" on its own is deliberately absent and must stay absent — it is a
# common given name, so a photo credited to a Claude would be flagged for the
# author's name rather than for anything about the image. The vendor-specific
# spellings below are the ones that actually appear in a claim generator.
AI_GENERATOR_RE='dall[[:punct:]]?e|midjourney|stable[[:space:]]?diffusion|firefly|imagen|gpt-image|anthropic|claude\.ai|sora|flux\.1|ideogram'

# has_c2pa_manifest <file> — a JUMBF/C2PA manifest store is present.
#
# Both markers must appear: "jumd" alone is a generic JUMBF description box and
# shows up in unrelated metadata, while the "c2pa" label is what makes the box
# tree a Content Credentials manifest store.
has_c2pa_manifest() { # <file>
  grep -aq 'jumd' "$1" 2>/dev/null && grep -aq 'c2pa' "$1" 2>/dev/null
}

# classify_image <file> — print a verdict token and return 0.
#
#   clean      no C2PA manifest at all
#   signed     manifest present, nothing indicating machine generation
#   ai:source  manifest asserts a machine-generated digitalSourceType
#   ai:tool    manifest names a known generative tool
#
# ai:source outranks ai:tool, and both fail. The distinction only shapes the
# message: "this image says it was generated" reads differently from "a
# generative tool appears in this image's history".
classify_image() { # <file>
  local file="$1" text=""

  if [ -n "$(command -v "$C2PATOOL_CMD" 2>/dev/null || true)" ]; then
    # c2patool exits non-zero for an asset with no manifest, which is a normal
    # outcome here rather than an error, so a failure falls through to the byte
    # scan instead of aborting the run.
    text="$("$C2PATOOL_CMD" "$file" 2>/dev/null || true)"
  fi

  # No c2patool, or it told us nothing: read the bytes. `strings` is not
  # guaranteed present (binutils is absent from slim images), so pull printable
  # runs out with tr, which is in POSIX. -cs collapses each run of
  # non-printables into one newline, so every embedded string lands on its own
  # line the way strings(1) would emit it.
  if [ -z "$text" ]; then
    if ! has_c2pa_manifest "$file"; then
      echo clean
      return 0
    fi
    text="$(tr -cs '[:print:]' '\n' <"$file" 2>/dev/null || true)"
  fi

  if printf '%s' "$text" | grep -qiE "$AI_SOURCE_TYPE_RE"; then
    echo ai:source
    return 0
  fi

  # Generator-name match, which is a weaker signal than the one above and is
  # treated as such: it says a generative tool's name appears somewhere in a
  # file that also carries a C2PA manifest, not that a specific manifest field
  # holds it. Field-accurate scoping is not available to a byte scan — CBOR puts
  # its string-length prefixes in the printable range, so a key and its value
  # cannot be reliably told apart from a neighbouring pair. The manifest
  # precondition in has_c2pa_manifest is what keeps this from firing on ordinary
  # files, and the allowlist is the remedy when it fires anyway.
  if printf '%s' "$text" | grep -qiE "$AI_GENERATOR_RE"; then
    echo ai:tool
    return 0
  fi

  echo signed
}

# ── Image check ───────────────────────────────────────────────────────────────

IMAGE_TOTAL=0
IMAGE_SIGNED=0
IMAGE_ALLOWED=0
IMAGE_BAD=()

check_images() {
  local dirs=() d
  for d in $AI_PROV_SCAN_DIRS; do
    [ -d "${AI_PROV_ROOT}/${d}" ] && dirs+=("${AI_PROV_ROOT}/${d}")
  done
  [ ${#dirs[@]} -eq 0 ] && return 0

  local file rel verdict
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    rel="${file#"${AI_PROV_ROOT}"/}"
    IMAGE_TOTAL=$((IMAGE_TOTAL + 1))

    verdict="$(classify_image "$file")"
    case "$verdict" in
      clean) ;;
      signed) IMAGE_SIGNED=$((IMAGE_SIGNED + 1)) ;;
      ai:*)
        if is_allowed "$rel"; then
          IMAGE_ALLOWED=$((IMAGE_ALLOWED + 1))
        else
          IMAGE_BAD+=("${verdict}"$'\t'"${rel}")
        fi
        ;;
    esac
  done < <(find "${dirs[@]}" -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
    -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.avif' -o -iname '*.tif' \
    -o -iname '*.tiff' \) 2>/dev/null | sort)
}

# ── Text check ────────────────────────────────────────────────────────────────
#
# Runs only when WATERMARK_DETECT_CMD is set. The seam is a command rather than
# a baked-in HTTP call because no vendor has published a detection API shape to
# code against: Anthropic's is in private preview with no documented endpoint,
# and SynthID's open-source detector needs the generating key, which only the
# generating vendor holds. A command contract lets whatever ships later be
# plugged in without touching this script.
#
# A watermark hit is NOT automatically a failure. Claude legitimately drafts
# content here (.claude/skills/blogmentation, the-unwind, /capture), so the
# rule is disclosure, not abstinence: a post that declares `aiAssisted` in its
# frontmatter passes with its hit recorded. An undeclared one fails.

TEXT_TOTAL=0
TEXT_DISCLOSED=0
TEXT_BAD=()
TEXT_ERRORS=()

check_text() {
  [ -n "$WATERMARK_DETECT_CMD" ] || return 0

  local dirs=() d
  for d in $AI_PROV_TEXT_DIRS; do
    [ -d "${AI_PROV_ROOT}/${d}" ] && dirs+=("${AI_PROV_ROOT}/${d}")
  done
  [ ${#dirs[@]} -eq 0 ] && return 0

  local file rel rc
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    rel="${file#"${AI_PROV_ROOT}"/}"

    # Drafts are not published, so they are not this gate's business yet.
    [ "$(fm_get "$file" draft)" = "true" ] && continue

    TEXT_TOTAL=$((TEXT_TOTAL + 1))

    set +e
    "$WATERMARK_DETECT_CMD" "$file" >/dev/null 2>&1
    rc=$?
    set -e

    case "$rc" in
      0) ;;
      10)
        if fm_has "$file" aiAssisted; then
          TEXT_DISCLOSED=$((TEXT_DISCLOSED + 1))
        else
          TEXT_BAD+=("$rel")
        fi
        ;;
      *) TEXT_ERRORS+=("${rel}"$'\t'"exit ${rc}") ;;
    esac
  done < <(find "${dirs[@]}" -type f -name '*.md' ! -name '_index.md' 2>/dev/null | sort)
}

# ── Run ───────────────────────────────────────────────────────────────────────

load_allowlist
check_images
check_text

STATUS=0

if [ ${#IMAGE_BAD[@]} -gt 0 ]; then
  STATUS=1
  echo "FAIL: ${#IMAGE_BAD[@]} of ${IMAGE_TOTAL} image(s) carry AI-generation provenance and are not disclosed" >&2
  echo "" >&2
  printf '%s\n' "${IMAGE_BAD[@]}" \
    | head -n "$AI_PROV_MAX_REPORT" \
    | awk -F'\t' '{
        what = ($1 == "ai:source") \
          ? "declares a machine-generated digitalSourceType" \
          : "names a generative AI tool in its provenance chain"
        printf "  %s\n      %s\n", $2, what
      }' >&2
  if [ ${#IMAGE_BAD[@]} -gt "$AI_PROV_MAX_REPORT" ]; then
    echo "  … and $((${#IMAGE_BAD[@]} - AI_PROV_MAX_REPORT)) more" >&2
  fi
  echo "" >&2
  echo "If the image is meant to be here, say so: add its path to" >&2
  echo "${AI_PROV_ALLOWLIST#"${REPO_ROOT}"/} with a comment naming what generated it." >&2
  echo "If it is not, replace it with one you made or shot yourself." >&2
fi

if [ ${#TEXT_ERRORS[@]} -gt 0 ]; then
  STATUS=1
  echo "" >&2
  echo "FAIL: the watermark detector errored on ${#TEXT_ERRORS[@]} file(s)" >&2
  printf '  %s\n' "${TEXT_ERRORS[@]}" >&2
  echo "" >&2
  echo "WATERMARK_DETECT_CMD must exit 0 (clean), 10 (watermark found), and" >&2
  echo "nothing else. An unexpected exit is treated as a broken gate, not a pass." >&2
fi

if [ ${#TEXT_BAD[@]} -gt 0 ]; then
  STATUS=1
  echo "" >&2
  echo "FAIL: ${#TEXT_BAD[@]} published file(s) carry an AI text watermark without disclosure" >&2
  printf '  %s\n' "${TEXT_BAD[@]}" >&2
  echo "" >&2
  echo "Either rewrite it in your own words, or disclose the assistance by adding" >&2
  echo "to that post's frontmatter:" >&2
  echo "" >&2
  echo "  aiAssisted:" >&2
  echo "    - draft" >&2
fi

[ "$STATUS" -eq 0 ] || exit 1

echo "OK: ${IMAGE_TOTAL} image(s) scanned for C2PA AI-generation markers, none undisclosed" \
  "(${IMAGE_SIGNED} signed but not AI-generated, ${IMAGE_ALLOWED} allowlisted)"

if [ -n "$WATERMARK_DETECT_CMD" ]; then
  echo "OK: ${TEXT_TOTAL} published file(s) checked for text watermarks" \
    "(${TEXT_DISCLOSED} disclosed via aiAssisted)"
else
  echo "SKIP: text watermark check — WATERMARK_DETECT_CMD is unset." \
    "See docs/ai-provenance.md."
fi
