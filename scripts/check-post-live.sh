#!/usr/bin/env bash
# Filter a list of post file paths down to the ones whose published page is live.
#
# Reads post paths (content/posts/<slug>.md) on stdin, one per line. For each,
# maps to its public URL (BASE_URL/posts/<slug>/) and probes it. Emits the paths
# whose page is reachable on stdout; logs a ::warning:: annotation for the rest.
# Always exits 0 — a not-yet-live post is a skip, not a failure.
#
# Used by .github/workflows/promote-post.yml ("Verify posts are live") so a
# social post is never published for a page that is not yet deployed, and so
# push-mode promotion waits out an in-flight Netlify deploy instead of racing it.
#
# Tunables (env):
#   BASE_URL        site origin (default https://kakkoyun.me)
#   LIVE_RETRIES    probe attempts per URL (default 20)
#   LIVE_SLEEP      seconds between attempts (default 15)
#   LIVE_PROBE_CMD  probe override for tests — a command that receives the URL as
#                   $1 and exits 0 when live. Defaults to a curl probe that
#                   treats HTTP 200 as live. Lets the unit tests run offline.
set -uo pipefail

BASE_URL="${BASE_URL:-https://kakkoyun.me}"
LIVE_RETRIES="${LIVE_RETRIES:-20}"
LIVE_SLEEP="${LIVE_SLEEP:-15}"

# Map content/posts/<slug>.md -> BASE_URL/posts/<slug>/
post_url() {
  local slug
  slug=$(basename "$1" .md)
  printf '%s/posts/%s/' "$BASE_URL" "$slug"
}

# Probe a URL. HTTP 200 == live. Overridable via LIVE_PROBE_CMD for offline tests.
probe() {
  local url="$1"
  if [ -n "${LIVE_PROBE_CMD:-}" ]; then
    "$LIVE_PROBE_CMD" "$url"
    return
  fi
  local code
  code=$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 10 "$url" || echo "000")
  [ "$code" = "200" ]
}

while IFS= read -r path; do
  [ -z "$path" ] && continue
  url=$(post_url "$path")
  ok=""
  for ((attempt = 1; attempt <= LIVE_RETRIES; attempt++)); do
    if probe "$url"; then
      ok="yes"
      break
    fi
    if [ "$attempt" -lt "$LIVE_RETRIES" ]; then
      echo "  $url not live yet (attempt $attempt/$LIVE_RETRIES), retrying in ${LIVE_SLEEP}s…" >&2
      sleep "$LIVE_SLEEP"
    fi
  done
  if [ -n "$ok" ]; then
    echo "Live: $url" >&2
    printf '%s\n' "$path"
  else
    echo "::warning::Skipping promotion — $url is not live. The post may not have deployed yet." >&2
  fi
done
