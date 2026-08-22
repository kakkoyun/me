#!/usr/bin/env bash
# List posts whose publishDate is today (UTC) and that are not drafts — i.e. the
# posts a fresh production build is expected to flip live today.
#
# Used by deploy-scheduled.yml to verify the nightly rebuild actually published
# new content. Netlify's atomic deploys keep the previous build serving HTTP 200
# throughout, so probing the homepage proves reachability, not that the new build
# is live. A today-dated post that becomes reachable does prove it.
#
# This is intentionally separate from find-promotable-posts.sh, and the split is
# wider than it used to be. That script asks "should this be *promoted*?" — a
# question with a lookback window and a promotedAt ledger behind it. This one
# asks "did today's *build* have anything to publish?", which is only ever about
# today and deliberately ignores `promote: false`: a post opted out of social
# promotion still has to go live.
#
# Talks are scanned alongside posts. They carry publishDate the same way, so a
# talk dated today needs the same rebuild to go live -- but a posts-only scan
# reported an empty day, deploy-scheduled.yml skipped the build hook, and on
# 2026-08-13 the GopherCon UK keynote page was still 404 on the day of the talk.
#
# Output: newline-separated content/<section>/*.md paths (empty = nothing due).
#
# Tunables (env):
#   TODAY_OVERRIDE  pin "today" (YYYY-MM-DD) for tests; defaults to UTC today.
#   POSTS_DIR       single directory to scan; overrides CONTENT_DIRS (tests).
#   CONTENT_DIRS    space-separated sections to scan (default: posts + talks).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/frontmatter.sh
source "${SCRIPT_DIR}/lib/frontmatter.sh"

TODAY="${TODAY_OVERRIDE:-$(date -u +%Y-%m-%d)}"
CONTENT_DIRS="${POSTS_DIR:-${CONTENT_DIRS:-content/posts content/talks}}"

# Word-splitting on CONTENT_DIRS is deliberate: it is a space-separated list.
# shellcheck disable=SC2086
for dir in $CONTENT_DIRS; do
  for post in "$dir"/*.md; do
    [ -f "$post" ] || continue

    pub=$(fm_get "$post" publishDate | cut -dT -f1)
    [ "$pub" = "$TODAY" ] || continue

    if fm_block "$post" | grep -q '^draft: true'; then
      continue
    fi

    printf '%s\n' "$post"
  done
done
