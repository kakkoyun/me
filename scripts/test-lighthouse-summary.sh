#!/usr/bin/env bash
# Unit tests for scripts/lighthouse-summary.sh
#
# Self-contained and offline: each case writes an assertion-results fixture and
# points the script at it via LHCI_RESULTS. No Lighthouse, no network.
#
# Fixtures here mirror what Lighthouse CI actually writes: FAILURES ONLY. An
# all-pass run writes `[]`. The first version of these tests used `passed: true`
# fixtures, a shape lhci never produces, and so happily passed while the script
# reported "All 0 assertion(s) passed" on a clean run — the exact false-success
# signal it exists to prevent.
#
# The cases that matter are the ones where the old setup went quiet: an empty
# file, a missing file, and a warn-level assertion that has been firing for
# weeks. All three must say something true.
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
#
# This is literally what lhci writes when nothing fails.

echo '[]' >"$TMP/results.json"
OUT=$(run success)
assert_contains "an empty results file is a clean run" "No assertion failures" "$OUT"
assert_not_contains "a clean run emits no table" "|---|" "$OUT"
assert_not_contains "a clean run invents no denominator" "of 0" "$OUT"
assert_not_contains "a clean run does not say 0 passed" "All 0" "$OUT"

# An empty file while Lighthouse itself failed means it fell over somewhere
# other than the assertions. Calling that a pass is the bug this script exists
# to prevent, so it must not.
echo '[]' >"$TMP/results.json"
OUT=$(run failure)
assert_contains "empty results plus a failed step is flagged" "recorded no failing assertions" "$OUT"
assert_not_contains "empty results plus a failed step is not a pass" "No assertion failures" "$OUT"

# --- an error-level failure ------------------------------------------------

cat >"$TMP/results.json" <<'JSON'
[{"auditId":"link-in-text-block","level":"error","passed":false,
  "operator":">=","expected":0.9,"actual":0,"values":[0,0,0]},
 {"auditId":"categories:accessibility","level":"error","passed":false,
  "operator":">=","expected":0.97,"actual":0.96,"values":[0.96,0.96,0.96]}]
JSON
OUT=$(run failure)
assert_contains "failures are counted" "2 assertion(s) failed" "$OUT"
assert_contains "the failing audit is named" "link-in-text-block" "$OUT"
assert_contains "the expected value is shown" ">= 0.9" "$OUT"
assert_contains "per-run values are shown" "0.96, 0.96, 0.96" "$OUT"
assert_contains "error level is called out" "2 of these are" "$OUT"
assert_not_contains "no denominator is invented" "of 2 assertion(s) failed" "$OUT"

# Defensive: if a future lhci ever does record passing entries, they must not be
# reported as failures.
cat >"$TMP/results.json" <<'JSON'
[{"auditId":"link-in-text-block","level":"error","passed":false,
  "operator":">=","expected":0.9,"actual":0,"values":[0,0,0]},
 {"auditId":"categories:seo","level":"error","passed":true,
  "operator":">=","expected":0.97,"actual":1,"values":[1,1,1]}]
JSON
OUT=$(run failure)
assert_contains "only the failing audit is counted" "1 assertion(s) failed" "$OUT"
assert_not_contains "a passing entry is not listed" "categories:seo" "$OUT"

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

# --- malformed input -------------------------------------------------------
#
# A truncated or corrupt file makes the parser exit nonzero. Under set -e that
# aborted the script, failing the job from a step that exists only to report —
# with a jq parse error and nothing about Lighthouse. A confusing red is no
# better than the silent green this replaced.

printf '[{"auditId":"x","level":"error","passed":fal' >"$TMP/results.json"
OUT=$(run failure)
assert_contains "truncated JSON is reported" "not valid JSON" "$OUT"
assert_not_contains "truncated JSON does not claim a pass" "No assertion failures" "$OUT"

printf 'not json at all\n' >"$TMP/results.json"
OUT=$(run success)
assert_contains "garbage input is reported" "not valid JSON" "$OUT"
assert_not_contains "garbage input does not claim a pass" "No assertion failures" "$OUT"

# A zero-byte file is a truncated write, not an all-pass run — that writes `[]`.
# jq reads empty input as no input and exits 0, so this needs its own guard.
printf '' >"$TMP/results.json"
OUT=$(run success)
assert_contains "a zero-byte file is reported" "present but empty" "$OUT"
assert_not_contains "a zero-byte file does not claim a pass" "No assertion failures" "$OUT"

printf '{"not":"an array"}\n' >"$TMP/results.json"
OUT=$(run success)
assert_contains "a JSON object instead of an array is reported" "not valid JSON" "$OUT"

# --- operational -----------------------------------------------------------

# The script must never gate, whatever it is fed. This is the property the
# header promises, so check it against every shape above rather than one.
for fixture in '[]' '[{"auditId":"a","level":"error","passed":false,"operator":">=","expected":1,"actual":0,"values":[0]}]' '[{"bad' 'not json' '' '{"o":1}'; do
  printf '%s' "$fixture" >"$TMP/results.json"
  for outcome in success failure ''; do
    set +e
    LHCI_RESULTS="$TMP/results.json" LHCI_OUTCOME="$outcome" bash "$SCRIPT" >/dev/null 2>&1
    rc=$?
    set -e
    if [ "$rc" != "0" ]; then
      fail "never gates (fixture '${fixture:0:12}', outcome '${outcome}')" "0" "$rc"
      continue 2
    fi
  done
done
pass "never exits nonzero, for any input shape or outcome"

rm -f "$TMP/results.json"
for outcome in success failure ''; do
  set +e
  LHCI_RESULTS="$TMP/results.json" LHCI_OUTCOME="$outcome" bash "$SCRIPT" >/dev/null 2>&1
  rc=$?
  set -e
  if [ "$rc" != "0" ]; then fail "never gates on a missing file (outcome '$outcome')" "0" "$rc"; fi
done
pass "never exits nonzero when the file is absent"

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
