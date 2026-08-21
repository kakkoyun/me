#!/usr/bin/env bash
# Stamp posts as promoted by appending to their `promotedAt` frontmatter list.
#
# This is the ledger that makes promotion idempotent. find-promotable-posts.sh
# skips any post that already carries a promotedAt entry, which is what lets the
# schedule-mode window be wider than a single day without re-posting the same
# link every morning.
#
# Usage:
#   printf '%s\n' content/posts/a.md | scripts/record-promotion.sh
#   scripts/record-promotion.sh --at 2026-08-17T00:00:00Z <<< content/posts/a.md
#
# Reads post paths on stdin, one per line. Echoes each stamped path to stdout.
#
# Options:
#   --at <iso8601>  timestamp to record instead of "now" (used by the backfill,
#                   which stamps historical posts with their own publishDate)
#
# Every edit is written to a temp file, validated, and only then moved over the
# original — a post that fails validation is left exactly as it was. Promotion
# runs unattended in CI against real content, so a half-rewritten post is a
# worse outcome than a failed run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/frontmatter.sh
source "${SCRIPT_DIR}/lib/frontmatter.sh"

STAMP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --at)
      STAMP="${2:?--at needs an ISO-8601 timestamp}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

STAMP="${STAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

# The one timestamp shape this repo writes. Also enforced by
# check-frontmatter.sh, so a bad --at fails here rather than in CI later.
ISO_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
if ! [[ "$STAMP" =~ $ISO_RE ]]; then
  echo "ERROR: --at must be YYYY-MM-DDTHH:MM:SSZ, got: $STAMP" >&2
  exit 1
fi

# Byte offset of the first character after the closing `---` line.
# LC_ALL=C so awk's length() counts bytes, not characters — post titles carry
# non-ASCII and a character count would put the offset in the wrong place.
frontmatter_end_offset() {
  LC_ALL=C awk '
    BEGIN { n = 0; off = 0 }
    { off += length($0) + 1
      if ($0 ~ /^---[[:space:]]*$/) { n++; if (n == 2) { print off; exit } } }
  ' "$1"
}

# Compare the two files byte-for-byte from the end of their frontmatter onward.
# This is the check that matters: fm_append_list rewrites the whole file, so the
# only proof it touched nothing but the frontmatter is the bytes themselves.
# An earlier version diffed awk output instead, which silently normalised a
# missing trailing newline and rewrote the last line of two real posts.
bodies_match() {
  local a_off b_off
  a_off=$(frontmatter_end_offset "$1")
  b_off=$(frontmatter_end_offset "$2")
  cmp -s \
    <(tail -c "+$((a_off + 1))" "$1") \
    <(tail -c "+$((b_off + 1))" "$2")
}

FAIL=0
STAMPED=0

while IFS= read -r post; do
  [ -z "$post" ] && continue

  if [ ! -f "$post" ]; then
    echo "ERROR: $post — file not found" >&2
    FAIL=1
    continue
  fi

  if [ -z "$(fm_block "$post")" ]; then
    echo "ERROR: $post — no frontmatter block" >&2
    FAIL=1
    continue
  fi

  before_count=$(fm_list "$post" promotedAt | wc -l | tr -d ' ')

  tmp=$(mktemp)
  fm_append_list "$post" promotedAt "$STAMP" >"$tmp"

  # awk terminates every record with a newline, so a source file that did not
  # end with one comes back with an extra byte. Two posts in this repo are like
  # that. Match the original rather than "fixing" it — a promotion stamp has no
  # business reformatting the end of someone's post.
  if [ -n "$(tail -c1 "$post")" ] && [ -z "$(tail -c1 "$tmp")" ]; then
    printf '%s' "$(cat "$tmp")" >"$tmp.trimmed" && mv "$tmp.trimmed" "$tmp"
  fi

  # ── Validation. Any failure leaves the original untouched. ────────────────
  err=""
  if [ "$(head -n1 "$tmp")" != "---" ]; then
    err="rewritten file does not open with ---"
  elif [ "$(grep -c '^---[[:space:]]*$' "$tmp")" -lt 2 ]; then
    err="rewritten file has no closing ---"
  elif [ -z "$(fm_block "$tmp")" ]; then
    err="rewritten frontmatter block is empty"
  elif [ "$(fm_list "$tmp" promotedAt | wc -l | tr -d ' ')" -ne "$((before_count + 1))" ]; then
    err="expected exactly one new promotedAt entry"
  elif [ "$(fm_list "$tmp" promotedAt | tail -n1)" != "$STAMP" ]; then
    err="new promotedAt entry is not the recorded timestamp"
  elif ! bodies_match "$post" "$tmp"; then
    err="post body changed"
  elif [ "$(fm_block "$tmp" | grep -c '^promotedAt:')" -ne 1 ]; then
    err="promotedAt declared more than once"
  else
    while IFS= read -r ts; do
      [[ "$ts" =~ $ISO_RE ]] || {
        err="malformed promotedAt entry: $ts"
        break
      }
    done < <(fm_list "$tmp" promotedAt)
  fi

  if [ -n "$err" ]; then
    echo "ERROR: $post — $err (left unchanged)" >&2
    rm -f "$tmp"
    FAIL=1
    continue
  fi

  # Preserve the original mode; mktemp creates 0600.
  chmod --reference="$post" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  mv "$tmp" "$post"
  STAMPED=$((STAMPED + 1))
  echo "$post"
done

echo "record-promotion: stamped $STAMPED post(s) at $STAMP" >&2
exit "$FAIL"
