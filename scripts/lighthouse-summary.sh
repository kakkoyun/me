#!/usr/bin/env bash
# Render Lighthouse CI assertion results as a GitHub Actions job summary.
#
# The Lighthouse step in build.yml is continue-on-error, so a failed assertion
# does not mark the job. That is how the assertions ran red for seven weeks
# while every run reported green: the job went green, and the one alarm — an
# auto-filed issue — silenced itself after the first failure because every
# later run found the issue already open and skipped.
#
# This turns the results into something visible on the run page itself, for
# pull requests as well as pushes, whether or not the job is allowed to fail.
#
# Usage: bash scripts/lighthouse-summary.sh >> "$GITHUB_STEP_SUMMARY"
#
# Tunables (env):
#   LHCI_RESULTS   assertion results JSON
#                  (default: .lighthouseci/assertion-results.json)
#   LHCI_OUTCOME   outcome of the Lighthouse step, used when there is no
#                  results file to tell "all passed" from "never ran"
#
# Always exits 0: this reports, it does not gate. Gating is .lighthouserc.yml's
# job, and whether a failure blocks a merge is continue-on-error's.
set -euo pipefail

LHCI_RESULTS="${LHCI_RESULTS:-.lighthouseci/assertion-results.json}"
LHCI_OUTCOME="${LHCI_OUTCOME:-}"

echo "## Lighthouse"
echo ""

if [ ! -f "$LHCI_RESULTS" ]; then
  # No file means lhci never got as far as asserting — a collect error, a
  # missing build, a crashed Chrome. Say so rather than implying success.
  if [ "$LHCI_OUTCOME" = "failure" ]; then
    echo "Lighthouse failed before it produced any assertion results."
  else
    echo "No assertion results were produced."
  fi
  echo ""
  echo "_Expected \`${LHCI_RESULTS}\`._"
  exit 0
fi

# jq is present on GitHub-hosted runners; python3 is the fallback so the script
# is runnable (and testable) anywhere.
if command -v jq >/dev/null 2>&1; then
  FAILED=$(jq '[.[] | select(.passed == false)] | length' "$LHCI_RESULTS")
  TOTAL=$(jq 'length' "$LHCI_RESULTS")
else
  FAILED=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(sum(1 for r in d if not r.get('passed')))" "$LHCI_RESULTS")
  TOTAL=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$LHCI_RESULTS")
fi

if [ "$FAILED" -eq 0 ]; then
  echo "All ${TOTAL} assertion(s) passed."
  exit 0
fi

ERRORS=0
echo "**${FAILED} of ${TOTAL} assertion(s) failed.**"
echo ""
echo "| Level | Audit | Expected | Actual | Runs |"
echo "|---|---|---|---|---|"

# Emit one row per failing assertion. Levels are error/warn as set in
# .lighthouserc.yml; both are shown, because a warn that has been firing for
# weeks is exactly the thing this script exists to surface.
while IFS=$'\t' read -r level audit operator expected actual values; do
  [ -z "$level" ] && continue
  [ "$level" = "error" ] && ERRORS=$((ERRORS + 1))
  echo "| ${level} | \`${audit}\` | ${operator} ${expected} | ${actual} | ${values} |"
done < <(
  if command -v jq >/dev/null 2>&1; then
    jq -r '.[] | select(.passed == false)
           | [.level, .auditId, .operator, (.expected|tostring),
              (.actual|tostring), ((.values // []) | map(tostring) | join(", "))]
           | @tsv' "$LHCI_RESULTS"
  else
    python3 -c "
import json, sys
for r in json.load(open(sys.argv[1])):
    if r.get('passed'): continue
    vals = ', '.join(str(v) for v in r.get('values', []))
    print('\t'.join([str(r.get('level','')), str(r.get('auditId','')),
                     str(r.get('operator','')), str(r.get('expected','')),
                     str(r.get('actual','')), vals]))
" "$LHCI_RESULTS"
  fi
)

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "${ERRORS} of these are \`error\` level in \`.lighthouserc.yml\`."
else
  echo "All of these are \`warn\` level in \`.lighthouserc.yml\`."
fi
echo ""
echo "_The Lighthouse step is \`continue-on-error\`, so these do not block a merge._"
