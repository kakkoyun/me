#!/usr/bin/env bash
# Assert that every <img> in the built site carries intrinsic dimensions.
#
# An <img> with no width and no height has no aspect ratio until its bytes
# arrive, so the browser lays the page out twice and everything below the image
# jumps. That is a cumulative-layout-shift regression, and Lighthouse reports it
# as `unsized-images`.
#
# This check exists because that regression kept coming back. The rule lived in
# a review comment and in a Lighthouse warning nobody read, while the layouts
# could not actually satisfy it: PaperMod's cover partial emitted a bare <img>
# for anything that was not a page-bundle resource, which was every cover on the
# site. 309 of the 539 <img> tags in a full build had no dimensions.
#
# The layouts were fixed (layouts/partials/functions/responsive-image.html is
# now the single place an <img> is produced, and it always emits width and
# height). This script is what keeps them fixed.
#
# Passing means one of:
#   - the tag has width= and height= attributes that are both positive whole
#     numbers, or
#   - the tag has a style= attribute setting both width: and height: to a
#     concrete length (Lighthouse accepts the CSS form, so this must too;
#     "auto", max-width and min-width do not count), or
#   - the tag's src matches a line in the allowlist.
#
# Usage: bash scripts/check-image-sizes.sh [public_dir]
#
# Tunables (env):
#   PUBLIC_DIR             directory to scan (default: public, or $1)
#   IMAGE_SIZE_ALLOWLIST   file of extended regexes matched against the src
#                          attribute; blank lines and #-comments are ignored
#                          (default: <repo>/scripts/image-size-allowlist.txt)
#   IMAGE_SIZE_MAX_REPORT  how many offenders to list before summarising
#                          (default: 25)
#
# Exits 0 when every <img> is sized; exits 1 and lists the offenders otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PUBLIC_DIR="${1:-${PUBLIC_DIR:-public}}"
IMAGE_SIZE_ALLOWLIST="${IMAGE_SIZE_ALLOWLIST:-${REPO_ROOT}/scripts/image-size-allowlist.txt}"
IMAGE_SIZE_MAX_REPORT="${IMAGE_SIZE_MAX_REPORT:-25}"

if [ ! -d "$PUBLIC_DIR" ]; then
  echo "ERROR: build directory not found: $PUBLIC_DIR" >&2
  echo "       run 'make production' first" >&2
  exit 1
fi

# The allowlist is optional; an absent file means "allow nothing".
ALLOW_ARG=""
if [ -f "$IMAGE_SIZE_ALLOWLIST" ]; then
  ALLOW_ARG="$IMAGE_SIZE_ALLOWLIST"
fi

# Hugo minifies attributes, so values may be quoted, single-quoted or bare, and
# a whole page is one very long line. Splitting the record on "<img" and taking
# everything up to the first ">" is a safe parse here because Go's html/template
# escapes ">" to "&gt;" inside attribute values.
# The awk program is deliberately single-quoted: its $0/$2 are awk fields, not
# shell variables, and the only value it needs from the shell arrives via -v.
# shellcheck disable=SC2016
REPORT=$(
  find "$PUBLIC_DIR" -type f -name '*.html' -print0 \
    | xargs -0 awk -v allowfile="$ALLOW_ARG" -v SQ="'" '
      BEGIN {
        nallow = 0
        if (allowfile != "") {
          while ((getline line < allowfile) > 0) {
            sub(/#.*/, "", line)
            gsub(/^[ \t]+|[ \t]+$/, "", line)
            if (line != "") allow[nallow++] = line
          }
          close(allowfile)
        }
      }

      # An attribute name is not a dimension: width="" and width="auto" both
      # have the attribute and still leave the browser with no aspect ratio to
      # reserve space with. Only a positive whole number counts.
      function is_positive_int(v) {
        gsub(/^[ \t\n\r]+|[ \t\n\r]+$/, "", v)
        if (v !~ /^[0-9]+$/) return 0
        return (v + 0) > 0
      }

      function attr_value(tag, name,   re, rest, v, q) {
        re = "[ \t\n\r/]" name "[ \t\n\r]*="
        if (!match(tag, re)) return ""
        rest = substr(tag, RSTART + RLENGTH)
        q = substr(rest, 1, 1)
        if (q == "\"" || q == SQ) {
          rest = substr(rest, 2)
          v = rest
          if (match(v, q)) v = substr(v, 1, RSTART - 1)
          return v
        }
        v = rest
        if (match(v, /[ \t\n\r]/)) v = substr(v, 1, RSTART - 1)
        return v
      }

      function is_allowed(src,   i) {
        for (i = 0; i < nallow; i++) if (src ~ allow[i]) return 1
        return 0
      }

      function scan(file, doc,   n, chunk, i, tag, p, style, src) {
        n = split(doc, chunk, /<img/)
        for (i = 2; i <= n; i++) {
          tag = chunk[i]
          p = index(tag, ">")
          if (p > 0) tag = substr(tag, 1, p - 1)
          # XHTML-style self-closing: the trailing slash in <img ... 600/> is
          # syntax, not part of the last unquoted attribute value.
          sub(/[ \t\n\r]*\/[ \t\n\r]*$/, "", tag)
          total++

          if (is_positive_int(attr_value(tag, "width")) &&
              is_positive_int(attr_value(tag, "height"))) continue

          # The CSS form, which Lighthouse also accepts. Anchor each property to
          # a declaration boundary so "width:" cannot match inside "max-width:",
          # and require a value that starts with a digit so "auto" is rejected.
          style = attr_value(tag, "style")
          if (style ~ /(^|;)[ \t]*width[ \t]*:[ \t]*[0-9]/ &&
              style ~ /(^|;)[ \t]*height[ \t]*:[ \t]*[0-9]/) continue

          src = attr_value(tag, "src")
          if (src == "") src = "(no src)"
          if (is_allowed(src)) { allowed++; continue }

          bad++
          print file "\t" src
        }
      }

      # A tag is only guaranteed to fit on one line in minified output, which is
      # what ships — but `hugo` without --minify pretty-prints, splitting a
      # single <img> across several lines. Buffer each file and scan it whole,
      # so the check means the same thing against either build.
      FNR == 1 {
        if (curfile != "") scan(curfile, buf)
        buf = ""
        curfile = FILENAME
      }

      { buf = buf " " $0 }

      END {
        if (curfile != "") scan(curfile, buf)
        print "__SUMMARY__\t" total "\t" bad "\t" allowed
      }
    '
)

SUMMARY=$(printf '%s\n' "$REPORT" | grep '^__SUMMARY__' | awk -F'\t' '{t+=$2; b+=$3; a+=$4} END {print t"\t"b"\t"a}')
TOTAL=$(printf '%s' "$SUMMARY" | cut -f1)
BAD=$(printf '%s' "$SUMMARY" | cut -f2)
ALLOWED=$(printf '%s' "$SUMMARY" | cut -f3)

if [ "${BAD:-0}" -eq 0 ]; then
  echo "OK: all ${TOTAL:-0} <img> tags in $PUBLIC_DIR carry width and height (${ALLOWED:-0} allowlisted)"
  exit 0
fi

echo "FAIL: ${BAD} of ${TOTAL} <img> tags have no width/height" >&2
echo "" >&2
# Group by src so one bad cover on 15 paginated pages reads as one problem.
printf '%s\n' "$REPORT" \
  | grep -v '^__SUMMARY__' \
  | awk -F'\t' '{count[$2]++; if (!($2 in where)) where[$2] = $1}
                END {for (s in count) printf "%6d  %s  (e.g. %s)\n", count[s], s, where[s]}' \
  | sort -rn \
  | head -n "$IMAGE_SIZE_MAX_REPORT" >&2
echo "" >&2
echo "Every <img> should come from layouts/partials/functions/responsive-image.html," >&2
echo "which always emits width and height. If one of these genuinely cannot be" >&2
echo "measured, give it cover.width/cover.height in frontmatter, or add its src to" >&2
echo "${IMAGE_SIZE_ALLOWLIST#"${REPO_ROOT}"/} with a comment saying why." >&2
exit 1
