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
# Output: newline-separated content/posts/*.md paths (empty = nothing due today).
#
# Tunables (env):
#   TODAY_OVERRIDE  pin "today" (YYYY-MM-DD) for tests; defaults to UTC today.
#   POSTS_DIR       directory to scan (default: content/posts).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/frontmatter.sh
source "${SCRIPT_DIR}/lib/frontmatter.sh"

TODAY="${TODAY_OVERRIDE:-$(date -u +%Y-%m-%d)}"
POSTS_DIR="${POSTS_DIR:-content/posts}"

for post in "$POSTS_DIR"/*.md; do
  [ -f "$post" ] || continue

  pub=$(fm_get "$post" publishDate | cut -dT -f1)
  [ "$pub" = "$TODAY" ] || continue

  if fm_block "$post" | grep -q '^draft: true'; then
    continue
  fi

  printf '%s\n' "$post"
done
