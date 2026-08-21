#!/usr/bin/env bash
# Unit tests for scripts/check-admin-csp.sh
#
# Self-contained and offline: every case builds a throwaway admin page and
# netlify.toml in a temp dir and points the checker at them via ADMIN_HTML /
# NETLIFY_CONFIG. No external test framework required.
#
# Usage: bash scripts/test-check-admin-csp.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/check-admin-csp.sh"

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

# ── Fixtures ─────────────────────────────────────────────────────────────────

INLINE_ONE='
      window.CMS_MANUAL_INIT = true;
    '
INLINE_TWO='
      CMS.init();
    '

hash_of() { printf '%s' "$1" | openssl dgst -sha256 -binary | openssl base64 -A; }

H1=$(hash_of "$INLINE_ONE")
H2=$(hash_of "$INLINE_TWO")

# An admin page with two inline blocks and a pinned, SRI-protected bundle.
write_admin_html() {
  cat >"$1" <<HTML
<!DOCTYPE html>
<html lang="en">
  <body>
    <script>${INLINE_ONE}</script>
    <script
      src="https://unpkg.com/@sveltia/cms@0.191.0/dist/sveltia-cms.js"
      integrity="sha384-vqs7J70ghmeGaGfUXWfvUK3kj+ssanA2dTEA5Uvu977zhm9tZzRB45Bz7wXO0Oux"
      crossorigin="anonymous"
    ></script>
    <script>${INLINE_TWO}</script>
  </body>
</html>
HTML
}

# A netlify.toml whose /admin/* CSP can be overridden per-case.
write_toml() {
  local out=$1 csp=$2 extra=${3:-}
  {
    printf '[[headers]]\n  for = "/*"\n\n  [headers.values]\n    X-Frame-Options = "DENY"\n\n'
    printf '[[headers]]\n  for = "/admin/*"\n\n  [headers.values]\n    X-Robots-Tag = "noindex, nofollow"\n'
    printf '    Content-Security-Policy-Report-Only = "%s"\n' "$csp"
    if [ -n "$extra" ]; then printf '    %s\n' "$extra"; fi
  } >"$out"
}

good_csp() {
  printf "default-src 'none'; script-src 'self' https://unpkg.com 'sha256-%s' 'sha256-%s'; connect-src 'self' https://api.github.com https://unpkg.com; frame-ancestors 'none'" "$H1" "$H2"
}

run_check() {
  local html=$1 toml=$2
  ADMIN_HTML="$html" NETLIFY_CONFIG="$toml" bash "$CHECK_SCRIPT" 2>&1
}

HTML="$TMP/index.html"
write_admin_html "$HTML"

# ── Cases ────────────────────────────────────────────────────────────────────

echo "check-admin-csp.sh"

# The real repo must pass. This is the case that actually protects production.
out=$(bash "$CHECK_SCRIPT" 2>&1) && rc=0 || rc=$?
assert_eq "the repo's own netlify.toml and admin page agree" "0" "$rc"

write_toml "$TMP/ok.toml" "$(good_csp)"
out=$(run_check "$HTML" "$TMP/ok.toml") && rc=0 || rc=$?
assert_eq "a matching policy passes" "0" "$rc"

# Editing the admin page without recomputing the hash is the whole point.
write_admin_html "$TMP/edited.html"
sed -i.bak 's/CMS.init();/CMS.init(); \/* new line *\//' "$TMP/edited.html"
out=$(run_check "$TMP/edited.html" "$TMP/ok.toml") && rc=0 || rc=$?
assert_eq "an edited inline script fails" "1" "$rc"
case "$out" in
  *"not pinned in script-src"*) pass "  ...and says which hash to add" ;;
  *) fail "  ...and says which hash to add" "not pinned in script-src" "$out" ;;
esac

# A hash left behind after an edit is dead weight and hides the real one.
write_toml "$TMP/stale.toml" "$(printf "default-src 'none'; script-src 'self' https://unpkg.com 'sha256-%s' 'sha256-%s' 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='; connect-src 'self' https://unpkg.com" "$H1" "$H2")"
out=$(run_check "$HTML" "$TMP/stale.toml") && rc=0 || rc=$?
assert_eq "a stale hash fails" "1" "$rc"

write_toml "$TMP/nohost.toml" "$(printf "default-src 'none'; script-src 'self' 'sha256-%s' 'sha256-%s'; connect-src 'self' https://unpkg.com" "$H1" "$H2")"
out=$(run_check "$HTML" "$TMP/nohost.toml") && rc=0 || rc=$?
assert_eq "a bundle origin missing from script-src fails" "1" "$rc"

write_toml "$TMP/noconnect.toml" "$(printf "default-src 'none'; script-src 'self' https://unpkg.com 'sha256-%s' 'sha256-%s'" "$H1" "$H2")"
out=$(run_check "$HTML" "$TMP/noconnect.toml") && rc=0 || rc=$?
assert_eq "a missing connect-src fails" "1" "$rc"

# Every shape of "connect anywhere" has to be rejected, not just the bare star:
# a scheme-only source and a wildcard host are equally unbounded.
i=0
for loose in "https:" "*" "https://*" "https://*.evil.example" "'self' https://*"; do
  i=$((i + 1))
  write_toml "$TMP/wildcard-$i.toml" "$(printf "default-src 'none'; script-src 'self' https://unpkg.com 'sha256-%s' 'sha256-%s'; connect-src 'self' https://unpkg.com %s" "$H1" "$H2" "$loose")"
  out=$(run_check "$HTML" "$TMP/wildcard-$i.toml") && rc=0 || rc=$?
  assert_eq "connect-src rejects '$loose'" "1" "$rc"
done

# ...while the keyword sources and real hosts the policy actually uses stay fine.
write_toml "$TMP/keywords.toml" "$(printf "default-src 'none'; script-src 'self' https://unpkg.com 'sha256-%s' 'sha256-%s'; connect-src 'self' 'none' https://api.github.com https://unpkg.com" "$H1" "$H2")"
out=$(run_check "$HTML" "$TMP/keywords.toml") && rc=0 || rc=$?
assert_eq "connect-src accepts keywords and explicit hosts" "0" "$rc"

# COOP breaks the sign-in popup. Adding it must never pass quietly.
write_toml "$TMP/coop.toml" "$(good_csp)" 'Cross-Origin-Opener-Policy = "same-origin"'
out=$(run_check "$HTML" "$TMP/coop.toml") && rc=0 || rc=$?
assert_eq "Cross-Origin-Opener-Policy on /admin/* fails" "1" "$rc"
case "$out" in
  *"breaks login"*) pass "  ...and explains why" ;;
  *) fail "  ...and explains why" "breaks login" "$out" ;;
esac

# A missing block is a config error, not a policy failure.
printf '[[headers]]\n  for = "/*"\n\n  [headers.values]\n    X-Frame-Options = "DENY"\n' >"$TMP/noadmin.toml"
out=$(run_check "$HTML" "$TMP/noadmin.toml") && rc=0 || rc=$?
assert_eq "a missing /admin/* header block fails" "1" "$rc"

# The enforcing header name must be accepted too — that is the PR 2 end state.
write_toml "$TMP/enforced.toml" "$(good_csp)"
sed -i.bak 's/Content-Security-Policy-Report-Only/Content-Security-Policy/' "$TMP/enforced.toml"
out=$(run_check "$HTML" "$TMP/enforced.toml") && rc=0 || rc=$?
assert_eq "an enforcing (non-Report-Only) policy passes" "0" "$rc"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
printf "  %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
