#!/usr/bin/env bash
# List posts whose publishDate is today (UTC) and that are not drafts — i.e. the
# posts a fresh production build is expected to flip live today.
#
# Used by deploy-scheduled.yml to verify the nightly rebuild actually published
# new content. Netlify's atomic deploys keep the previous build serving HTTP 200
# throughout, so probing the homepage proves reachability, not that the new build
# is live. A today-dated post that becomes reachable does prove it.
#
# This is intentionally separate from find-promotable-posts.sh: that filters for
# *promotion* (honours `promote: false`, dedups against the push trigger). For a
# *publish* check we want every today-dated, non-draft post, including ones opted
# out of social promotion.
#
# Output: newline-separated content/posts/*.md paths (empty = nothing due today).
#
# Tunables (env):
#   TODAY_OVERRIDE  pin "today" (YYYY-MM-DD) for tests; defaults to UTC today.
set -euo pipefail

TODAY="${TODAY_OVERRIDE:-$(date -u +%Y-%m-%d)}"
POSTS_DIR="${POSTS_DIR:-content/posts}"

frontmatter() {
  # Emit only the YAML frontmatter block (lines between the first two `---`).
  # Mirrors scripts/find-promotable-posts.sh so parsing stays consistent.
  awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if (n==2) exit; next} n==1' "$1"
}

for post in "$POSTS_DIR"/*.md; do
  [ -f "$post" ] || continue
  fm=$(frontmatter "$post")

  pub=$(printf '%s\n' "$fm" | grep -m1 '^publishDate:' | awk '{print $2}' | tr -d '"' | cut -dT -f1 || true)
  [ "$pub" = "$TODAY" ] || continue

  if printf '%s\n' "$fm" | grep -q '^draft: true'; then
    continue
  fi

  printf '%s\n' "$post"
done
