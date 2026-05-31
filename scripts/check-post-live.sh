#!/usr/bin/env bash
# Filter a list of post file paths down to the ones whose published page is live.
#
# Reads post paths (content/posts/<slug>.md) on stdin, one per line. For each,
# maps to its public URL (BASE_URL/posts/<slug>/) and probes it. Emits the paths
# whose page is reachable on stdout; logs a ::warning:: annotation for the rest.
# Always exits 0 — a not-yet-live post is a skip, not a failure.
#
# Used by:
#   - promote-post.yml ("Verify posts are live") so a social post is never
#     published for a page that is not yet deployed.
#   - deploy-scheduled.yml, to confirm a today-dated post actually went live
#     after the rebuild (a fresh-build check, not just reachability).
#
# Retries share ONE global time budget (LIVE_MAX_WAIT), not a per-post budget:
# we wait out the single in-flight deploy once, and every subsequent URL is then
# checked against the same deadline. Worst-case runtime is bounded regardless of
# how many posts are passed in.
#
# Tunables (env):
#   BASE_URL        site origin (default https://kakkoyun.me)
#   LIVE_MAX_WAIT   total seconds to keep retrying across all posts (default 300)
#   LIVE_SLEEP      seconds between attempts (default 15)
#   LIVE_PROBE_CMD  probe override for tests — a command that receives the URL as
#                   $1 and exits 0 when live. Defaults to a curl probe that
#                   treats HTTP 200 as live. Lets the unit tests run offline.
set -uo pipefail

BASE_URL="${BASE_URL:-https://kakkoyun.me}"
LIVE_MAX_WAIT="${LIVE_MAX_WAIT:-300}"
LIVE_SLEEP="${LIVE_SLEEP:-15}"

deadline=$(( $(date +%s) + LIVE_MAX_WAIT ))

# Map content/posts/<slug>.md -> BASE_URL/posts/<slug>/
post_url() {
  local slug
  slug=$(basename "$1" .md)
  printf '%s/posts/%s/' "$BASE_URL" "$slug"
}

# Probe a URL. HTTP 200 == live. Overridable via LIVE_PROBE_CMD for offline tests.
# No `curl -f`: --fail would mask the real status (404/500 → 000), making the
# logs misleading. Without it, curl exits 0 and -w reports the true code; only a
# transport error (no response) falls back to 000.
probe() {
  local url="$1"
  if [ -n "${LIVE_PROBE_CMD:-}" ]; then
    "$LIVE_PROBE_CMD" "$url"
    return
  fi
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$url") || code="000"
  [ "$code" = "200" ] && return 0
  echo "  $url → HTTP $code" >&2
  return 1
}

# Probe until live or the global deadline passes.
probe_until_live() {
  local url="$1"
  while true; do
    probe "$url" && return 0
    [ "$(date +%s)" -ge "$deadline" ] && return 1
    sleep "$LIVE_SLEEP"
  done
}

while IFS= read -r path; do
  [ -z "$path" ] && continue
  url=$(post_url "$path")
  if probe_until_live "$url"; then
    echo "Live: $url" >&2
    printf '%s\n' "$path"
  else
    echo "::warning::Skipping — $url is not live within the wait budget. The post may not have deployed yet." >&2
  fi
done
