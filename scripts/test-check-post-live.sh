#!/usr/bin/env bash
# Unit tests for scripts/check-post-live.sh
#
# Self-contained and offline: the live probe is stubbed via LIVE_PROBE_CMD so no
# network is touched. No external test framework required.
#
# Usage: bash scripts/test-check-post-live.sh
set -euo pipefail

CHECK_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-post-live.sh"

PASS=0
FAIL=0

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; (( PASS += 1 )); }
fail() {
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
  printf "         expected: %s\n" "${2:-<empty>}"
  printf "         actual:   %s\n" "${3:-<empty>}"
  (( FAIL += 1 ))
}

assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "$2" "$3"; fi
}

# ── Probe stubs ───────────────────────────────────────────────────────────────
# A probe receives the URL as $1 and exits 0 when "live". The tests inject these
# via LIVE_PROBE_CMD. Runs are fast and offline: LIVE_RETRIES=1, LIVE_SLEEP=0.

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Live iff the URL contains the marker "live".
cat > "$TMP/probe-by-marker.sh" <<'EOF'
#!/usr/bin/env bash
case "$1" in *live*) exit 0 ;; *) exit 1 ;; esac
EOF

# Always live, and append the URL it was handed to $PROBE_LOG (for URL-mapping checks).
cat > "$TMP/probe-record.sh" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "$PROBE_LOG"
exit 0
EOF

# Always dead.
cat > "$TMP/probe-dead.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

chmod +x "$TMP"/probe-*.sh

run() {
  # run <stdin-string> — invokes the script with fast, stubbed settings.
  # The probe is chosen by the caller via the LIVE_PROBE_CMD env it sets.
  LIVE_RETRIES=1 LIVE_SLEEP=0 "$CHECK_SCRIPT"
}

echo "── check-post-live ─────────────────────────────────────"

# Live post passes through unchanged.
out=$(LIVE_PROBE_CMD="$TMP/probe-by-marker.sh" run <<< "content/posts/live-post.md")
assert_eq "live post is emitted" "content/posts/live-post.md" "$out"

# Dead post is filtered out (empty stdout).
out=$(LIVE_PROBE_CMD="$TMP/probe-dead.sh" run <<< "content/posts/whatever.md")
assert_eq "dead post is dropped" "" "$out"

# Dead post emits a ::warning:: on stderr.
err=$(LIVE_PROBE_CMD="$TMP/probe-dead.sh" run <<< "content/posts/whatever.md" 2>&1 >/dev/null)
case "$err" in
  *"::warning::"*"not live"*) pass "dead post warns on stderr" ;;
  *) fail "dead post warns on stderr" "::warning:: ... not live" "$err" ;;
esac

# Mixed batch: only the live one survives, order preserved.
out=$(LIVE_PROBE_CMD="$TMP/probe-by-marker.sh" run <<EOF
content/posts/dead-one.md
content/posts/live-two.md
content/posts/dead-three.md
EOF
)
assert_eq "mixed batch keeps only live posts" "content/posts/live-two.md" "$out"

# URL mapping: content/posts/<slug>.md -> BASE_URL/posts/<slug>/
PROBE_LOG="$TMP/urls.log"; : > "$PROBE_LOG"
LIVE_PROBE_CMD="$TMP/probe-record.sh" PROBE_LOG="$PROBE_LOG" BASE_URL="https://example.test" \
  run <<< "content/posts/my-cool-post.md" >/dev/null
assert_eq "maps post path to public URL" \
  "https://example.test/posts/my-cool-post/" "$(cat "$PROBE_LOG")"

# Default BASE_URL is the production origin.
PROBE_LOG="$TMP/urls2.log"; : > "$PROBE_LOG"
LIVE_PROBE_CMD="$TMP/probe-record.sh" PROBE_LOG="$PROBE_LOG" \
  run <<< "content/posts/hello.md" >/dev/null
assert_eq "default BASE_URL is kakkoyun.me" \
  "https://kakkoyun.me/posts/hello/" "$(cat "$PROBE_LOG")"

# Blank lines are ignored, not treated as a post.
PROBE_LOG="$TMP/urls3.log"; : > "$PROBE_LOG"
out=$(LIVE_PROBE_CMD="$TMP/probe-record.sh" PROBE_LOG="$PROBE_LOG" run <<EOF

content/posts/only-real.md

EOF
)
assert_eq "blank lines ignored (output)" "content/posts/only-real.md" "$out"
assert_eq "blank lines ignored (one probe)" "1" "$(wc -l < "$PROBE_LOG" | tr -d ' ')"

# Empty stdin -> empty output, clean exit.
out=$(LIVE_PROBE_CMD="$TMP/probe-by-marker.sh" run <<< "")
assert_eq "empty input yields no output" "" "$out"

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "$((PASS + FAIL)) tests run — $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
