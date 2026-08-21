#!/usr/bin/env bash
# Asserts that the set of accounts with push access to this repo is exactly the
# expected one.
#
# This is the invariant the whole CMS access model rests on. Signing in to
# /admin/ mints a GitHub App user-to-server token, and such a token carries only
# `app permissions ∩ user permissions ∩ where the app is installed`. There is no
# allowlist inside Sveltia: "who can edit the site" is precisely "who can push
# to this repo". Add a collaborator for some unrelated reason and you have
# silently granted them the CMS.
#
# Usage:
#   bash scripts/check-repo-access.sh
#
# Tunables (env):
#   GITHUB_TOKEN / GH_TOKEN  API token. Without one the check SKIPS (so a
#                            contributor running `make test` locally is not
#                            blocked) unless REQUIRE_TOKEN=1.
#   REQUIRE_TOKEN            set to 1 in CI so a missing token fails loudly
#                            instead of skipping the check entirely.
#   REPO_SLUG                owner/repo (default kakkoyun/me)
#   EXPECTED_PUSHERS         space-separated logins allowed push (default kakkoyun)
#   ACCESS_API_CMD           API override for tests — a command that receives the
#                            API path as $1 and prints the JSON response.
#
# Exits 0 when the push set matches; 1 when it does not.
set -uo pipefail

REPO_SLUG="${REPO_SLUG:-kakkoyun/me}"
EXPECTED_PUSHERS="${EXPECTED_PUSHERS:-kakkoyun}"
REQUIRE_TOKEN="${REQUIRE_TOKEN:-0}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

api() {
  if [ -n "${ACCESS_API_CMD:-}" ]; then
    "$ACCESS_API_CMD" "$1"
    return
  fi
  curl -sS --max-time 20 \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/$1"
}

# Entry count of a JSON array, or a non-zero exit if it is not one.
count_entries() {
  python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(1) if not isinstance(d, list) else print(len(d))'
}

# Concatenate two JSON arrays.
merge_arrays() {
  python3 -c '
import json, sys
a = json.loads(sys.argv[1])
b = json.loads(sys.argv[2])
print(json.dumps(a + b))
' "$1" "$2"
}

if [ -z "$TOKEN" ] && [ -z "${ACCESS_API_CMD:-}" ]; then
  if [ "$REQUIRE_TOKEN" = "1" ]; then
    echo "::error::REQUIRE_TOKEN=1 but no GITHUB_TOKEN/GH_TOKEN is set — the repo access check did not run" >&2
    exit 1
  fi
  echo "SKIP: no GITHUB_TOKEN/GH_TOKEN — repo access check needs one (CI sets it)"
  exit 0
fi

# Paginate. `per_page=100` is a page size, not "everything" — with more than one
# page, an extra pusher on page 2 would be invisible and the exact-set invariant
# would pass while being false. Keep asking until a page comes back short.
PER_PAGE=100
MAX_PAGES="${MAX_PAGES:-50}"
PAGE=1
RESPONSE="[]"
while :; do
  if [ "$PAGE" -gt "$MAX_PAGES" ]; then
    echo "::error::still paginating collaborators for ${REPO_SLUG} after ${MAX_PAGES} pages — refusing to loop." >&2
    echo "  Either the repo really has >$((MAX_PAGES * PER_PAGE)) collaborators (in which case this" >&2
    echo "  check is the least of your problems) or the API is not advancing." >&2
    exit 1
  fi

  chunk=$(api "repos/${REPO_SLUG}/collaborators?affiliation=all&per_page=${PER_PAGE}&page=${PAGE}")

  if [ -z "$chunk" ]; then
    echo "::error::empty response from the collaborators API for ${REPO_SLUG} (page ${PAGE})" >&2
    exit 1
  fi

  case "$chunk" in
    *'"message"'*)
      echo "::error::the collaborators API rejected the request for ${REPO_SLUG}." >&2
      printf '%s\n' "$chunk" | head -5 >&2
      echo "" >&2
      echo "  This endpoint needs Administration: read, which a workflow GITHUB_TOKEN" >&2
      echo "  cannot be granted — 'administration' is not a settable permissions key." >&2
      echo "  Run this with a token that has it (your own gh session does), or set" >&2
      echo "  REPO_ADMIN_TOKEN in CI. See docs/sveltia-cms.md." >&2
      exit 1
      ;;
  esac

  count=$(printf '%s' "$chunk" | count_entries) || count=-1
  if [ "$count" -lt 0 ]; then
    echo "::error::could not parse the collaborators response for ${REPO_SLUG}" >&2
    printf '%s\n' "$chunk" | head -20 >&2
    exit 1
  fi

  RESPONSE=$(merge_arrays "$RESPONSE" "$chunk")
  [ "$count" -lt "$PER_PAGE" ] && break
  PAGE=$((PAGE + 1))
done

ACTUAL=$(printf '%s' "$RESPONSE" | python3 -c '
import json, sys
for c in json.load(sys.stdin):
    if c.get("permissions", {}).get("push"):
        print(c["login"])
' 2>/dev/null | sort -u)
PARSE_RC=$?

if [ "$PARSE_RC" -ne 0 ] || [ -z "$ACTUAL" ]; then
  echo "::error::could not parse the collaborators response for ${REPO_SLUG}" >&2
  printf '%s\n' "$RESPONSE" | head -20 >&2
  exit 1
fi

# Intentionally unquoted: EXPECTED_PUSHERS is a space-separated list.
# shellcheck disable=SC2086
EXPECTED=$(printf '%s\n' $EXPECTED_PUSHERS | sort)

if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "::error::push access to ${REPO_SLUG} is not what the CMS access model assumes." >&2
  echo "  expected: $(printf '%s' "$EXPECTED" | tr '\n' ' ')" >&2
  echo "  actual:   $(printf '%s' "$ACTUAL" | tr '\n' ' ')" >&2
  echo "" >&2
  echo "  Anyone in that list can sign in to /admin/ and commit through the CMS." >&2
  echo "  If this change was intended, update EXPECTED_PUSHERS in" >&2
  echo "  .github/workflows/links.yml and say so in docs/sveltia-cms.md." >&2
  exit 1
fi

echo "OK: push access to ${REPO_SLUG} is exactly: $(printf '%s' "$ACTUAL" | tr '\n' ' ')"
