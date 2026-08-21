#!/usr/bin/env bash
# Asserts that the deployed site is actually serving the security headers
# declared in netlify.toml.
#
# scripts/check-admin-csp.sh proves the config says the right thing. This proves
# Netlify is serving it — which is a different claim, and the one that matters
# after a merge, a Netlify config change, or a plugin update. Header rules are
# invisible in the build output, so nothing else in CI would notice them
# silently going away.
#
# The expected header set is read from netlify.toml rather than hardcoded, so
# the file and the live response cannot drift apart.
#
# Usage:
#   bash scripts/check-live-headers.sh                       # production
#   BASE_URL="$DEPLOY_PRIME_URL" bash scripts/check-live-headers.sh
#
# Tunables (env):
#   BASE_URL             site origin (default https://kakkoyun.me)
#   NETLIFY_CONFIG       path to netlify.toml (default: <repo>/netlify.toml)
#   HEADERS_MAX_WAIT     total seconds to keep retrying (default 300). Shared
#                        across both URLs, like check-post-live.sh: we wait out
#                        one in-flight deploy, not one per request.
#   HEADERS_SLEEP        seconds between attempts (default 15)
#   HEADERS_PROBE_CMD    probe override for tests — a command that receives the
#                        URL as $1 and prints the response headers on stdout.
#                        Lets the unit tests run offline.
#   EXPECT_CSP_ENFORCED  set to 1 once the policy has been flipped off
#                        Report-Only; the check then fails if production is
#                        still serving Content-Security-Policy-Report-Only.
#
# Exits 0 when every expected header is present and correct; 1 otherwise.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BASE_URL="${BASE_URL:-https://kakkoyun.me}"
NETLIFY_CONFIG="${NETLIFY_CONFIG:-${REPO_ROOT}/netlify.toml}"
HEADERS_MAX_WAIT="${HEADERS_MAX_WAIT:-300}"
HEADERS_SLEEP="${HEADERS_SLEEP:-15}"
EXPECT_CSP_ENFORCED="${EXPECT_CSP_ENFORCED:-0}"

BASE_URL="${BASE_URL%/}"
deadline=$(($(date +%s) + HEADERS_MAX_WAIT))

ERRORS=0
fail() {
  echo "::error::$1"
  ERRORS=$((ERRORS + 1))
}

if [ ! -f "$NETLIFY_CONFIG" ]; then
  echo "ERROR: not found: $NETLIFY_CONFIG" >&2
  exit 1
fi

# ── Expected headers, read out of netlify.toml ───────────────────────────────
# Emits "<name>" per line for the named `for = "..."` block. Values are not
# compared verbatim: Netlify normalises whitespace, and the CSP's own contents
# are already guarded by check-admin-csp.sh. Presence is what this script owns.
header_names_for() {
  awk -v want="$1" '
    /^\[\[headers\]\]/ { active = 0 }
    /^[[:space:]]*for[[:space:]]*=/ {
      line = $0
      sub(/^[^"]*"/, "", line)
      sub(/".*$/, "", line)
      active = (line == want)
      next
    }
    active && /^[[:space:]]*[A-Za-z][A-Za-z0-9-]*[[:space:]]*=/ {
      name = $1
      if (name != "for") print name
    }
  ' "$NETLIFY_CONFIG"
}

mapfile -t SITE_HEADERS < <(header_names_for "/*")
mapfile -t ADMIN_HEADERS < <(header_names_for "/admin/*")

if [ "${#SITE_HEADERS[@]}" -eq 0 ] || [ "${#ADMIN_HEADERS[@]}" -eq 0 ]; then
  echo "ERROR: could not read header names from $NETLIFY_CONFIG" >&2
  exit 1
fi

# ── Fetching ─────────────────────────────────────────────────────────────────
# Follows redirects (-L) so a trailing-slash bounce still lands on the real
# response. No `curl -f`: a --fail would hide the status code we want to report.
fetch_headers() {
  local url="$1"
  if [ -n "${HEADERS_PROBE_CMD:-}" ]; then
    "$HEADERS_PROBE_CMD" "$url"
    return
  fi
  curl -sSL -o /dev/null -D - --max-time 15 "$url"
}

# Fetch until the response carries a marker header, or the shared deadline
# passes. A deploy in flight serves the old build, which has no such header —
# so "marker missing" and "not deployed yet" are the same wait.
fetch_until_present() {
  local url="$1" marker="$2" out
  while true; do
    out=$(fetch_headers "$url")
    if printf '%s\n' "$out" | grep -qi "^${marker}:"; then
      printf '%s\n' "$out"
      return 0
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      printf '%s\n' "$out"
      return 1
    fi
    sleep "$HEADERS_SLEEP"
  done
}

has_header() {
  printf '%s\n' "$1" | grep -qi "^${2}:"
}

header_value() {
  printf '%s\n' "$1" | grep -i "^${2}:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r'
}

# ── / — the site-wide baseline ───────────────────────────────────────────────
echo "Checking $BASE_URL/"
ROOT=$(fetch_until_present "$BASE_URL/" "X-Content-Type-Options") \
  || fail "$BASE_URL/ never served X-Content-Type-Options within ${HEADERS_MAX_WAIT}s — headers not deployed?"

for h in "${SITE_HEADERS[@]}"; do
  if has_header "$ROOT" "$h"; then
    echo "  $h: $(header_value "$ROOT" "$h")"
  else
    fail "$BASE_URL/ is missing $h"
  fi
done

# A CSP on the blog pages would be a mistake, not an upgrade: the theme's inline
# scripts would need 'unsafe-inline', which makes the policy decorative. If one
# ever appears here it was added without the refactor that would justify it.
if has_header "$ROOT" "Content-Security-Policy" || has_header "$ROOT" "Content-Security-Policy-Report-Only"; then
  fail "$BASE_URL/ unexpectedly serves a Content-Security-Policy; the site-wide policy is deliberately absent (see netlify.toml)"
fi

# ── /admin/ — the CMS ────────────────────────────────────────────────────────
echo "Checking $BASE_URL/admin/"
ADMIN=$(fetch_until_present "$BASE_URL/admin/" "X-Robots-Tag") \
  || fail "$BASE_URL/admin/ never served X-Robots-Tag within ${HEADERS_MAX_WAIT}s"

for h in "${SITE_HEADERS[@]}"; do
  has_header "$ADMIN" "$h" || fail "$BASE_URL/admin/ is missing the site-wide header $h"
done

for h in "${ADMIN_HEADERS[@]}"; do
  # The two CSP header names are checked below instead: which of them is correct
  # depends on EXPECT_CSP_ENFORCED, and netlify.toml only ever declares one.
  case "$h" in
    Content-Security-Policy | Content-Security-Policy-Report-Only) continue ;;
  esac
  if has_header "$ADMIN" "$h"; then
    echo "  $h present"
  else
    fail "$BASE_URL/admin/ is missing $h"
  fi
done

case "$(header_value "$ADMIN" "X-Robots-Tag")" in
  *noindex*) ;;
  *) fail "$BASE_URL/admin/ X-Robots-Tag does not say noindex" ;;
esac

# COOP breaks the sign-in popup (see check-admin-csp.sh). Catch it here too, in
# case it arrives from Netlify UI config rather than from netlify.toml.
if has_header "$ADMIN" "Cross-Origin-Opener-Policy"; then
  fail "$BASE_URL/admin/ serves Cross-Origin-Opener-Policy — it severs window.opener and breaks Sveltia sign-in"
fi

if [ "$EXPECT_CSP_ENFORCED" = "1" ]; then
  if has_header "$ADMIN" "Content-Security-Policy-Report-Only"; then
    fail "expected an enforcing CSP but $BASE_URL/admin/ still serves Content-Security-Policy-Report-Only"
  fi
  has_header "$ADMIN" "Content-Security-Policy" \
    || fail "expected $BASE_URL/admin/ to serve an enforcing Content-Security-Policy"
elif ! has_header "$ADMIN" "Content-Security-Policy" && ! has_header "$ADMIN" "Content-Security-Policy-Report-Only"; then
  fail "$BASE_URL/admin/ serves no Content-Security-Policy at all"
fi

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "FAILED: $ERRORS check(s) failed" >&2
  exit 1
fi

echo "OK: live security headers match netlify.toml"
