#!/usr/bin/env bash
# Unit tests for scripts/check-live-headers.sh
#
# Self-contained and offline: the HTTP fetch is stubbed via HEADERS_PROBE_CMD,
# which prints canned response headers per URL. No network is touched, and the
# retry budget is set to 0 so failures return immediately.
#
# Usage: bash scripts/test-check-live-headers.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/check-live-headers.sh"

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

# ── Fixture config ───────────────────────────────────────────────────────────
cat >"$TMP/netlify.toml" <<'TOML'
[[headers]]
  for = "/*"

  [headers.values]
    X-Content-Type-Options = "nosniff"
    Referrer-Policy = "strict-origin-when-cross-origin"
    X-Frame-Options = "DENY"

[[headers]]
  for = "/admin/*"

  [headers.values]
    X-Robots-Tag = "noindex, nofollow"
    Content-Security-Policy-Report-Only = "default-src 'none'"
TOML

# ── Probe stubs ──────────────────────────────────────────────────────────────
# A probe receives the URL as $1 and prints response headers on stdout. Each
# stub sources $HDR_DIR/<name> so the cases can vary one header at a time.

make_probe() {
  # $1 = probe path, $2 = extra lines for /admin/, $3 = lines to drop (grep -v pattern)
  local path=$1 admin_extra=$2 drop=${3:-__nothing__}
  cat >"$path" <<PROBE
#!/usr/bin/env bash
common='HTTP/2 200
x-content-type-options: nosniff
referrer-policy: strict-origin-when-cross-origin
x-frame-options: DENY'
case "\$1" in
  */admin/*)
    printf '%s\n' "\$common"
    printf '%s\n' 'x-robots-tag: noindex, nofollow'
    printf '%s\n' '${admin_extra}'
    ;;
  *)
    printf '%s\n' "\$common"
    ;;
esac
PROBE
  # shellcheck disable=SC2016
  if [ "$drop" != "__nothing__" ]; then
    printf '%s\n' "# drop: $drop" >>"$path"
    sed -i.bak "/${drop}/d" "$path"
  fi
  chmod +x "$path"
}

run_check() {
  HEADERS_PROBE_CMD="$1" \
    NETLIFY_CONFIG="$TMP/netlify.toml" \
    BASE_URL="https://example.test" \
    HEADERS_MAX_WAIT=0 HEADERS_SLEEP=0 \
    EXPECT_CSP_ENFORCED="${2:-0}" \
    bash "$CHECK_SCRIPT" 2>&1
}

echo "check-live-headers.sh"

# ── Cases ────────────────────────────────────────────────────────────────────

make_probe "$TMP/ok.sh" "content-security-policy-report-only: default-src 'none'"
out=$(run_check "$TMP/ok.sh") && rc=0 || rc=$?
assert_eq "a fully-headed response passes" "0" "$rc"

make_probe "$TMP/no-nosniff.sh" "content-security-policy-report-only: default-src 'none'" "x-content-type-options"
out=$(run_check "$TMP/no-nosniff.sh") && rc=0 || rc=$?
assert_eq "a missing site-wide header fails" "1" "$rc"

make_probe "$TMP/no-csp.sh" "x-permitted-cross-domain-policies: none"
out=$(run_check "$TMP/no-csp.sh") && rc=0 || rc=$?
assert_eq "an /admin/ response with no CSP fails" "1" "$rc"
case "$out" in
  *"no Content-Security-Policy at all"*) pass "  ...and says so" ;;
  *) fail "  ...and says so" "no Content-Security-Policy at all" "$out" ;;
esac

# COOP is the one header whose *presence* is the bug.
make_probe "$TMP/coop.sh" "content-security-policy-report-only: default-src 'none'
cross-origin-opener-policy: same-origin"
out=$(run_check "$TMP/coop.sh") && rc=0 || rc=$?
assert_eq "Cross-Origin-Opener-Policy on /admin/ fails" "1" "$rc"

# Report-Only is correct before the flip and wrong after it.
out=$(run_check "$TMP/ok.sh" 1) && rc=0 || rc=$?
assert_eq "Report-Only fails once EXPECT_CSP_ENFORCED=1" "1" "$rc"

make_probe "$TMP/enforced.sh" "content-security-policy: default-src 'none'"
out=$(run_check "$TMP/enforced.sh" 1) && rc=0 || rc=$?
assert_eq "an enforcing CSP passes with EXPECT_CSP_ENFORCED=1" "0" "$rc"

# A CSP on the blog pages means someone added one without the theme refactor.
cat >"$TMP/root-csp.sh" <<'PROBE'
#!/usr/bin/env bash
printf '%s\n' 'HTTP/2 200'
printf '%s\n' 'x-content-type-options: nosniff'
printf '%s\n' 'referrer-policy: strict-origin-when-cross-origin'
printf '%s\n' 'x-frame-options: DENY'
case "$1" in
  */admin/*)
    printf '%s\n' 'x-robots-tag: noindex, nofollow'
    printf '%s\n' "content-security-policy-report-only: default-src 'none'"
    ;;
  *) printf '%s\n' "content-security-policy: default-src 'self'" ;;
esac
PROBE
chmod +x "$TMP/root-csp.sh"
out=$(run_check "$TMP/root-csp.sh") && rc=0 || rc=$?
assert_eq "an unexpected CSP on / fails" "1" "$rc"

# The site-wide baseline has to reach /admin/ too, not just the blog.
cat >"$TMP/admin-bare.sh" <<'PROBE'
#!/usr/bin/env bash
case "$1" in
  */admin/*)
    printf '%s\n' 'HTTP/2 200'
    printf '%s\n' 'x-robots-tag: noindex, nofollow'
    printf '%s\n' "content-security-policy-report-only: default-src 'none'"
    ;;
  *)
    printf '%s\n' 'HTTP/2 200'
    printf '%s\n' 'x-content-type-options: nosniff'
    printf '%s\n' 'referrer-policy: strict-origin-when-cross-origin'
    printf '%s\n' 'x-frame-options: DENY'
    ;;
esac
PROBE
chmod +x "$TMP/admin-bare.sh"
out=$(run_check "$TMP/admin-bare.sh") && rc=0 || rc=$?
assert_eq "site-wide headers missing from /admin/ fails" "1" "$rc"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
printf "  %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
