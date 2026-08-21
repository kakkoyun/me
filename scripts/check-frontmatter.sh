#!/usr/bin/env bash
# Assert that every post carries the frontmatter the publishing pipeline needs.
#
# The scripts that drive publishing and promotion read frontmatter with grep and
# awk, so a missing or misshapen field does not raise an error — it silently
# reads as empty, and the post quietly drops out of the pipeline. That is how a
# post gets published but never promoted, with nothing in any log to say why.
# This check turns those silent drops into a failed build.
#
# Hugo already validates the YAML itself: build.yml runs a full production build
# on every PR and Hugo refuses to parse a malformed frontmatter block. So this
# script deliberately does not attempt to be a YAML parser. It checks the domain
# rules Hugo has no opinion about.
#
# Rules, per non-_index.md file in content/posts/:
#   - a frontmatter block exists
#   - date is present            (CLAUDE.md: "Always include both")
#   - publishDate is present and is YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ
#   - promotedAt, when present, is a block list of YYYY-MM-DDTHH:MM:SSZ values
#
# Usage: bash scripts/check-frontmatter.sh
#
# Tunables (env):
#   POSTS_DIR  directory to scan (default: <repo>/content/posts)
#
# Exits 0 when every post passes; exits 1 and lists the offenders otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/frontmatter.sh
source "${SCRIPT_DIR}/lib/frontmatter.sh"

POSTS_DIR="${POSTS_DIR:-${REPO_ROOT}/content/posts}"

DATE_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$'
STAMP_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'

if [ ! -d "$POSTS_DIR" ]; then
  echo "ERROR: posts directory not found: $POSTS_DIR" >&2
  exit 1
fi

FAIL=0
CHECKED=0

problem() {
  echo "INVALID: $1 — $2" >&2
  FAIL=1
}

for post in "$POSTS_DIR"/*.md; do
  [ -f "$post" ] || continue
  [ "$(basename "$post")" = "_index.md" ] && continue
  CHECKED=$((CHECKED + 1))

  rel="${post#"${REPO_ROOT}"/}"

  if [ -z "$(fm_block "$post")" ]; then
    problem "$rel" "no frontmatter block"
    continue
  fi

  fm_has "$post" date || problem "$rel" "missing 'date'"

  pub=$(fm_get "$post" publishDate)
  if [ -z "$pub" ]; then
    problem "$rel" "missing 'publishDate' — it would never be published or promoted"
  elif ! [[ "$pub" =~ $DATE_RE ]]; then
    problem "$rel" "publishDate is not YYYY-MM-DD[THH:MM:SSZ]: '$pub'"
  fi

  if fm_has "$post" promotedAt; then
    # An inline flow list (`promotedAt: [...]`) parses as an empty block list,
    # which would read as "never promoted" and re-promote the post. Reject it.
    if [ -n "$(fm_get "$post" promotedAt)" ]; then
      problem "$rel" "promotedAt must be a block list ('- value' on its own line), not inline"
    elif [ -z "$(fm_list "$post" promotedAt)" ]; then
      problem "$rel" "promotedAt is declared but empty"
    else
      while IFS= read -r stamp; do
        [[ "$stamp" =~ $STAMP_RE ]] \
          || problem "$rel" "promotedAt entry is not YYYY-MM-DDTHH:MM:SSZ: '$stamp'"
      done < <(fm_list "$post" promotedAt)
    fi
  fi
done

if [ "$CHECKED" -eq 0 ]; then
  echo "ERROR: no posts found in $POSTS_DIR" >&2
  exit 1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "OK: $CHECKED posts have valid publishing frontmatter."
else
  echo "" >&2
  echo "Posts missing these fields drop out of the publishing and promotion" >&2
  echo "pipeline silently. See the frontmatter contract in CLAUDE.md." >&2
  exit 1
fi
