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
# What the results file contains: Lighthouse CI records only assertions that
# FAILED. An all-pass run writes `[]`. So the file gives no denominator — the
# number of assertions actually checked is not knowable from it, and any "N of M"
# phrasing built on it is fiction. Report the failures and nothing more.
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
# is runnable (and testable) anywhere. Parse once, into tab-separated rows.
extract_rows() {
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
}

# A truncated or malformed file makes the parser exit nonzero, and under set -e
# that would abort this script — failing the job from a step whose whole purpose
# is to report without gating, with a parse error and nothing about Lighthouse.
# A confusing red is no better than the silent green this replaced.
# A zero-byte file is not an all-pass run — that writes `[]`, two bytes. It
# means the write was interrupted. jq reads empty input as no input and exits 0,
# so without this the summary would read "No assertion failures" and be wrong in
# exactly the way this script exists to prevent. (The python3 fallback raises,
# so the two backends disagreed here too.)
if [ ! -s "$LHCI_RESULTS" ]; then
  echo "Could not read \`${LHCI_RESULTS}\` — it is present but empty."
  echo ""
  echo "_An all-pass run writes \`[]\`, so this is a truncated write, not a clean run._"
  exit 0
fi

if ! ROWS=$(extract_rows 2>/dev/null); then
  echo "Could not read \`${LHCI_RESULTS}\` — it is present but not valid JSON."
  echo ""
  echo "_Lighthouse may have been interrupted while writing it. Check the step log._"
  exit 0
fi

FAILED=$(printf '%s' "$ROWS" | grep -c . || true)

if [ "$FAILED" -eq 0 ]; then
  # No recorded failures. Only call that a pass if Lighthouse agrees — an empty
  # file alongside a failed step means it fell over somewhere other than the
  # assertions, and reporting "all passed" there is the false-success signal
  # this script exists to prevent.
  if [ "$LHCI_OUTCOME" = "failure" ]; then
    echo "Lighthouse reported a failure but recorded no failing assertions."
    echo ""
    echo "_Something failed outside the assertions — check the step log._"
  else
    echo "No assertion failures."
  fi
  exit 0
fi

ERRORS=0
echo "**${FAILED} assertion(s) failed.**"
echo ""
echo "| Level | Audit | Expected | Actual | Runs |"
echo "|---|---|---|---|---|"

# Levels are error/warn as set in .lighthouserc.yml; both are shown, because a
# warn that has been firing for weeks is exactly what this script exists to
# surface.
while IFS=$'\t' read -r level audit operator expected actual values; do
  [ -z "$level" ] && continue
  [ "$level" = "error" ] && ERRORS=$((ERRORS + 1))
  echo "| ${level} | \`${audit}\` | ${operator} ${expected} | ${actual} | ${values} |"
done <<EOF
$ROWS
EOF

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "${ERRORS} of these are \`error\` level in \`.lighthouserc.yml\`."
else
  echo "All of these are \`warn\` level in \`.lighthouserc.yml\`."
fi
echo ""
echo "_The Lighthouse step is \`continue-on-error\`, so these do not block a merge._"
