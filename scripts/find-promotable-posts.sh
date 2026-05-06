#!/usr/bin/env bash
# Find posts eligible for social media promotion.
# All date/draft logic is deterministic — no AI involved.
#
# Usage:
#   find-promotable-posts.sh push          # Push trigger: newly added, publishable today
#   find-promotable-posts.sh schedule      # Cron trigger: any post with publishDate == today (deduped)
#   find-promotable-posts.sh manual <path> # Manual: validate single post (skip date check)
#
# Output: newline-separated list of promotable post paths (empty = nothing to promote)
set -euo pipefail

MODE="${1:-push}"
TODAY=$(date -u +%Y-%m-%d)

is_draft() {
  grep -q '^draft: true' "$1"
}

get_publish_date() {
  # Extract publishDate from YAML frontmatter, return date portion only (YYYY-MM-DD)
  grep '^publishDate:' "$1" | head -1 | awk '{print $2}' | tr -d '"' | cut -dT -f1
}

file_added_date() {
  # Date file was first added to git (for dedup between push and cron triggers)
  git log --diff-filter=A --format=%cs -- "$1" | head -1
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

  if [ "$skip_date_check" = "false" ]; then
    local pub_date
    pub_date=$(get_publish_date "$post")
    if [ -z "$pub_date" ]; then
      echo "SKIP $post — no publishDate" >&2
      return 1
    fi
    if [[ "$pub_date" > "$TODAY" ]]; then
      echo "SKIP $post — future publishDate ($pub_date > $TODAY)" >&2
      return 1
    fi
  fi

  return 0
}

case "$MODE" in
  push)
    # Only newly added files in this commit
    posts=$(git diff --diff-filter=A --name-only HEAD~1 HEAD -- 'content/posts/*.md' 2>/dev/null || true)
    while IFS= read -r post; do
      [ -z "$post" ] && continue
      if validate_post "$post"; then
        echo "$post"
      fi
    done <<< "$posts"
    ;;

  schedule)
    # Scan ALL posts for publishDate == today, with dedup
    for post in content/posts/*.md; do
      [ -f "$post" ] || continue

      pub_date=$(get_publish_date "$post")
      if [ "$pub_date" != "$TODAY" ]; then
        continue
      fi

      if is_draft "$post"; then
        echo "SKIP $post — draft" >&2
        continue
      fi

      # Dedup: if file was added today, push trigger already promoted it
      add_date=$(file_added_date "$post")
      if [ "$add_date" = "$TODAY" ]; then
        echo "SKIP $post — added today, already promoted by push trigger" >&2
        continue
      fi

      echo "$post"
    done
    ;;

  manual)
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
