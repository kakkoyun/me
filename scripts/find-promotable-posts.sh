#!/usr/bin/env bash
# Find posts eligible for social media promotion.
# All date/draft/ledger logic is deterministic — no AI involved.
#
# Usage:
#   find-promotable-posts.sh schedule      # Cron/manual: everything due and unpromoted
#   find-promotable-posts.sh manual <path> # Manual: validate single post (skip date/ledger checks)
#
# Output: newline-separated list of promotable post paths (empty = nothing to promote)
#
# ── How schedule mode decides ─────────────────────────────────────────────────
#
# A post is promotable when all of these hold:
#
#   not draft            — unpublished work is not announced
#   promote is not false  — explicit opt-out, see CLAUDE.md
#   publishDate <= today  — the page is actually live (production builds omit
#                           --buildFuture, so a future publishDate is a 404)
#   publishDate >= today - PROMOTE_LOOKBACK_DAYS
#                         — don't wake up the archive
#   promotedAt is empty   — it has not already gone out
#
# This deliberately replaced an exact `publishDate == today` match. That gave
# each post a single one-day window: a post merged after its publishDate had
# passed, or merged after the 06:00 cron on its own publish day, was never
# promoted and was not even logged as skipped. Widening the window is only safe
# because promotedAt records what already went out — scripts/record-promotion.sh
# writes it after a successful run. The window and the ledger are one mechanism;
# neither works without the other.
#
# Tunables (env):
#   TODAY_OVERRIDE        pin "today" (YYYY-MM-DD) for tests; defaults to UTC today.
#   PROMOTE_LOOKBACK_DAYS how far back to look for unpromoted posts (default 30).
#   POSTS_DIR             directory to scan (default: content/posts).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/frontmatter.sh
source "${SCRIPT_DIR}/lib/frontmatter.sh"

MODE="${1:-schedule}"
TODAY="${TODAY_OVERRIDE:-$(date -u +%Y-%m-%d)}"
LOOKBACK_DAYS="${PROMOTE_LOOKBACK_DAYS:-30}"
POSTS_DIR="${POSTS_DIR:-content/posts}"

is_draft() {
  fm_block "$1" | grep -q '^draft: true'
}

skip_promotion() {
  fm_block "$1" | grep -q '^promote: false'
}

already_promoted() {
  [ -n "$(fm_list "$1" promotedAt)" ]
}

get_publish_date() {
  # publishDate as YYYY-MM-DD. Empty (exit 0) when missing — callers handle it.
  fm_get "$1" publishDate | cut -dT -f1
}

# Earliest publishDate still eligible. GNU date and BSD date disagree on the
# flag, so try both: CI is Linux, the author's machine is macOS.
cutoff_date() {
  date -u -d "${TODAY} -${LOOKBACK_DAYS} days" +%Y-%m-%d 2>/dev/null \
    || date -u -j -f %Y-%m-%d -v-"${LOOKBACK_DAYS}"d "$TODAY" +%Y-%m-%d
}

validate_post() {
  local post="$1"
  local skip_date_check="${2:-false}"

  if [ ! -f "$post" ]; then
    echo "SKIP $post — file not found" >&2
    return 1
  fi

  if is_draft "$post"; then
    echo "SKIP $post — draft" >&2
    return 1
  fi

  if skip_promotion "$post"; then
    echo "SKIP $post — promote: false" >&2
    return 1
  fi

  if [ "$skip_date_check" = "false" ]; then
    local pub_date cutoff
    pub_date=$(get_publish_date "$post")
    if [ -z "$pub_date" ]; then
      echo "SKIP $post — no publishDate" >&2
      return 1
    fi
    # Lexicographic compare is safe and locale-proof for YYYY-MM-DD.
    if [[ "$pub_date" > "$TODAY" ]]; then
      echo "SKIP $post — future publishDate ($pub_date > $TODAY)" >&2
      return 1
    fi
    cutoff=$(cutoff_date)
    if [[ "$pub_date" < "$cutoff" ]]; then
      echo "SKIP $post — publishDate $pub_date older than $LOOKBACK_DAYS-day lookback (< $cutoff)" >&2
      return 1
    fi
    if already_promoted "$post"; then
      echo "SKIP $post — already promoted ($(fm_list "$post" promotedAt | tail -n1))" >&2
      return 1
    fi
  fi

  return 0
}

case "$MODE" in
  schedule)
    for post in "$POSTS_DIR"/*.md; do
      [ -f "$post" ] || continue
      [ "$(basename "$post")" = "_index.md" ] && continue
      if validate_post "$post" "false"; then
        echo "$post"
      fi
    done
    ;;

  manual)
    # The deliberate "promote now / again" button: skips the date window and the
    # promotedAt ledger, so a human can re-promote on purpose. Still stamped
    # afterwards by record-promotion.sh.
    POST="${2:?Usage: find-promotable-posts.sh manual <path>}"
    if validate_post "$POST" "true"; then
      echo "$POST"
    fi
    ;;

  *)
    echo "Unknown mode: $MODE" >&2
    exit 1
    ;;
esac
