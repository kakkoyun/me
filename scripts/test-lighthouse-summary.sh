#!/usr/bin/env bash
# Unit tests for scripts/lighthouse-summary.sh
#
# Self-contained and offline: each case writes an assertion-results fixture and
# points the script at it via LHCI_RESULTS. No Lighthouse, no network.
#
# The cases that matter are the ones where the old setup went quiet: a failure
# that produces no results file, and a warn-level assertion that has been firing
# for weeks. Both must still say something.
#
# Usage: bash scripts/test-lighthouse-summary.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lighthouse-summary.sh"

PASS=0
FAIL=0
pass() {
  printf "  \033[32mPASS\033[0m  %s\n" "$1"
  ((PASS += 1))
}
fail() {
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
  printf "         expected: %s\n" "$2"
  printf "         actual:   %s\n" "$3"
  ((FAIL += 1))
}
assert_contains() {
  case "$3" in
    *"$2"*) pass "$1" ;;
    *) fail "$1" "output containing '$2'" "$(printf '%s' "$3" | tr '\n' '|')" ;;
  esac
}
assert_not_contains() {
  case "$3" in
    *"$2"*) fail "$1" "output NOT containing '$2'" "$(printf '%s' "$3" | tr '\n' '|')" ;;
    *) pass "$1" ;;
  esac
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

run() { LHCI_RESULTS="$TMP/results.json" LHCI_OUTCOME="${1:-}" bash "$SCRIPT" 2>&1; }

echo "lighthouse-summary.sh"

# --- everything passed -----------------------------------------------------

cat >"$TMP/results.json" <<'JSON'
[{"auditId":"categories:performance","level":"error","passed":true,
  "operator":">=","expected":0.9,"actual":0.99,"values":[0.99,0.99,0.99]}]
JSON
OUT=$(run success)
assert_contains "a clean run says so" "All 1 assertion(s) passed" "$OUT"
assert_not_contains "a clean run emits no table" "|---|" "$OUT"

# --- an error-level failure ------------------------------------------------

cat >"$TMP/results.json" <<'JSON'
[{"auditId":"link-in-text-block","level":"error","passed":false,
  "operator":">=","expected":0.9,"actual":0,"values":[0,0,0]},
 {"auditId":"categories:seo","level":"error","passed":true,
  "operator":">=","expected":0.97,"actual":1,"values":[1,1,1]}]
JSON
OUT=$(run failure)
assert_contains "a failure is counted" "1 of 2 assertion(s) failed" "$OUT"
assert_contains "the failing audit is named" "link-in-text-block" "$OUT"
assert_contains "the expected value is shown" ">= 0.9" "$OUT"
assert_contains "per-run values are shown" "0, 0, 0" "$OUT"
assert_contains "error level is called out" "1 of these are" "$OUT"
assert_not_contains "passing audits are not listed" "categories:seo" "$OUT"

# --- a warn-level failure --------------------------------------------------
#
# This is the seven-week case: warn-level assertions never blocked anything and
# never appeared anywhere, so nobody knew they were firing.

cat >"$TMP/results.json" <<'JSON'
[{"auditId":"errors-in-console","level":"warn","passed":false,
  "operator":">=","expected":0.9,"actual":0,"values":[0,0,0]}]
JSON
OUT=$(run success)
assert_contains "a warn-level failure is still reported" "errors-in-console" "$OUT"
assert_contains "warn-only runs say so" "All of these are" "$OUT"

# --- no results file -------------------------------------------------------
#
# lhci can die before asserting. Silence here would read as success, which is
# the exact failure mode this script exists to prevent.

rm -f "$TMP/results.json"
OUT=$(run failure)
assert_contains "a crash before asserting is reported" "failed before it produced" "$OUT"
assert_not_contains "a crash never claims success" "passed" "$OUT"

OUT=$(run "")
assert_contains "a missing file with no outcome is reported" "No assertion results" "$OUT"

# --- operational -----------------------------------------------------------

cat >"$TMP/results.json" <<'JSON'
[{"auditId":"categories:performance","level":"error","passed":false,
  "operator":">=","expected":0.9,"actual":0.42,"values":[0.42,0.41,0.43]}]
JSON
set +e
LHCI_RESULTS="$TMP/results.json" bash "$SCRIPT" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" = "0" ]; then
  pass "reporting a failure still exits 0 (it reports, it does not gate)"
else
  fail "reporting a failure still exits 0" "0" "$rc"
fi

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
