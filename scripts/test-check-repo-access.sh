#!/usr/bin/env bash
# Unit tests for scripts/check-repo-access.sh
#
# Self-contained and offline: the GitHub API call is stubbed via ACCESS_API_CMD,
# which prints canned JSON. No network and no token required.
#
# Usage: bash scripts/test-check-repo-access.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/check-repo-access.sh"

PASS=0
FAIL=0

pass() {
  printf "  \033[32mPASS\033[0m  %s\n" "$1"
  ((PASS += 1))
}
fail() {
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
  printf "         expected: %s\n" "${2:-<empty>}"
  printf "         actual:   %s\n" "${3:-<empty>}"
  ((FAIL += 1))
}

assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "$2" "$3"; fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── API stubs ────────────────────────────────────────────────────────────────
# Each receives the API path as $1 and prints a collaborators payload.

stub() {
  cat >"$TMP/$1.sh" <<PROBE
#!/usr/bin/env bash
cat <<'JSON'
$2
JSON
PROBE
  chmod +x "$TMP/$1.sh"
}

stub solo '[{"login":"kakkoyun","permissions":{"push":true,"admin":true}}]'
stub extra '[{"login":"kakkoyun","permissions":{"push":true,"admin":true}},
             {"login":"someone-else","permissions":{"push":true,"admin":false}}]'
stub readonly '[{"login":"kakkoyun","permissions":{"push":true,"admin":true}},
                {"login":"a-reader","permissions":{"push":false,"admin":false}}]'
stub garbage 'not json at all'

run_check() {
  ACCESS_API_CMD="$TMP/$1.sh" \
    REPO_SLUG="kakkoyun/me" \
    EXPECTED_PUSHERS="${2:-kakkoyun}" \
    bash "$CHECK_SCRIPT" 2>&1
}

echo "check-repo-access.sh"

out=$(run_check solo) && rc=0 || rc=$?
assert_eq "a single expected pusher passes" "0" "$rc"

out=$(run_check extra) && rc=0 || rc=$?
assert_eq "an unexpected collaborator with push fails" "1" "$rc"
case "$out" in
  *"can sign in to /admin/"*) pass "  ...and explains the CMS consequence" ;;
  *) fail "  ...and explains the CMS consequence" "can sign in to /admin/" "$out" ;;
esac

# Read-only collaborators cannot commit, so they are not a CMS grant.
out=$(run_check readonly) && rc=0 || rc=$?
assert_eq "a read-only collaborator is ignored" "0" "$rc"

# Widening the allowlist is how an intentional change is recorded.
out=$(run_check extra "kakkoyun someone-else") && rc=0 || rc=$?
assert_eq "an expanded EXPECTED_PUSHERS accepts the new collaborator" "0" "$rc"

out=$(run_check garbage) && rc=0 || rc=$?
assert_eq "an unparseable response fails rather than passing" "1" "$rc"

# Without a token the check must skip, not silently claim success...
out=$(env -u GITHUB_TOKEN -u GH_TOKEN -u ACCESS_API_CMD bash "$CHECK_SCRIPT" 2>&1) && rc=0 || rc=$?
assert_eq "no token skips" "0" "$rc"
case "$out" in
  SKIP*) pass "  ...and says SKIP" ;;
  *) fail "  ...and says SKIP" "SKIP..." "$out" ;;
esac

# ...but CI sets REQUIRE_TOKEN=1, where a missing token is itself the bug.
out=$(env -u GITHUB_TOKEN -u GH_TOKEN -u ACCESS_API_CMD REQUIRE_TOKEN=1 bash "$CHECK_SCRIPT" 2>&1) && rc=0 || rc=$?
assert_eq "no token with REQUIRE_TOKEN=1 fails" "1" "$rc"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
printf "  %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
