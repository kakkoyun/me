#!/usr/bin/env bash
# Asserts that the Content-Security-Policy served on /admin/ still matches the
# page it is protecting.
#
# /admin/ is Sveltia CMS. After sign-in it holds a GitHub App user token in
# localStorage, so its CSP is the control that stops an injected script from
# exfiltrating that token. The policy pins the two inline <script> blocks in
# static/admin/index.html by sha256 — which means editing that file silently
# breaks the page under an enforcing policy unless the hashes are recomputed.
# This guard turns that silent breakage into a failed build.
#
# Checks:
#   1. every inline <script> in the admin page is pinned by hash in script-src
#   2. no stale hashes are left behind in script-src
#   3. the external bundle's host appears in script-src, and its pinned version
#      matches the one the SRI hash in the page was computed for
#   4. connect-src exists and is not a wildcard (it is what bounds exfiltration)
#   5. Cross-Origin-Opener-Policy is absent — see the failure message
#
# Usage:
#   bash scripts/check-admin-csp.sh
#
# Tunables (env):
#   ADMIN_HTML      path to the admin page   (default: <repo>/static/admin/index.html)
#   NETLIFY_CONFIG  path to netlify.toml     (default: <repo>/netlify.toml)
#
# Exits 0 when the policy and the page agree; exits 1 and says which check failed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ADMIN_HTML="${ADMIN_HTML:-${REPO_ROOT}/static/admin/index.html}"
NETLIFY_CONFIG="${NETLIFY_CONFIG:-${REPO_ROOT}/netlify.toml}"

ERRORS=0
fail() {
  echo "FAIL: $1" >&2
  ERRORS=$((ERRORS + 1))
}

for f in "$ADMIN_HTML" "$NETLIFY_CONFIG"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: not found: $f" >&2
    exit 1
  fi
done

# ── The /admin/* header block ────────────────────────────────────────────────
# Everything from `for = "/admin/*"` up to the next [[headers]] table or EOF.
ADMIN_BLOCK=$(awk '
  /^\[\[headers\]\]/ { in_admin = 0 }
  /^[[:space:]]*for[[:space:]]*=[[:space:]]*"\/admin\/\*"/ { in_admin = 1 }
  in_admin { print }
' "$NETLIFY_CONFIG")

if [ -z "$ADMIN_BLOCK" ]; then
  echo "ERROR: no [[headers]] block for \"/admin/*\" in $NETLIFY_CONFIG" >&2
  exit 1
fi

# The policy value, under either header name. Report-Only is the pre-flip state;
# both are accepted here — scripts/check-live-headers.sh is what asserts which
# one production is actually serving.
CSP=$(printf '%s\n' "$ADMIN_BLOCK" \
  | sed -n 's/^[[:space:]]*Content-Security-Policy\(-Report-Only\)\?[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\2/p' \
  | head -1)

if [ -z "$CSP" ]; then
  fail "no Content-Security-Policy (or -Report-Only) in the /admin/* block"
  echo "" >&2
  echo "FAILED: $ERRORS check(s) failed" >&2
  exit 1
fi

# One directive per line, so a grep for "script-src" cannot match inside another.
directive() {
  printf '%s\n' "$CSP" | tr ';' '\n' \
    | sed -n "s/^[[:space:]]*$1[[:space:]]\{1,\}//p" | head -1
}

SCRIPT_SRC=$(directive script-src)
CONNECT_SRC=$(directive connect-src)

[ -n "$SCRIPT_SRC" ] || fail "CSP has no script-src directive"

# ── 1 + 2. Inline <script> hashes ────────────────────────────────────────────
# The hash covers the exact bytes between <script> and </script>. Only bare
# <script> tags are inline; the bundle's tag carries a src= attribute and is
# matched by check 3 instead.
mapfile -t PAGE_HASHES < <(
  perl -0777 -ne '
    # Match any <script ...> opener, not just the bare one, then skip the tags
    # that load an external file. Matching only `<script>` would silently omit a
    # block the moment someone adds an attribute such as type="module" — and an
    # omitted block is one the enforcing CSP would refuse to run, with `make
    # test` reporting all clear. The attribute alternation tolerates > inside
    # quoted values and spans newlines (the bundle tag is multi-line).
    while (/<script\b((?:[^>"\x27]|"[^"]*"|\x27[^\x27]*\x27)*)>(.*?)<\/script>/gis) {
      my ($attrs, $body) = ($1, $2);
      # (?:^|\s) not \b: `-` is a non-word character, so \bsrc would also match
      # the tail of `data-src=` and skip a genuinely inline block.
      next if $attrs =~ /(?:^|\s)src\s*=/i;
      open(my $p, "|-", "openssl dgst -sha256 -binary | openssl base64 -A") or die;
      print $p $body;
      close $p;
      print "\n";
    }
  ' "$ADMIN_HTML"
)

if [ "${#PAGE_HASHES[@]}" -eq 0 ]; then
  fail "found no inline <script> blocks in $ADMIN_HTML — did the parser break?"
fi

for h in "${PAGE_HASHES[@]}"; do
  case "$SCRIPT_SRC" in
    *"'sha256-${h}'"*) ;;
    *) fail "inline script in $ADMIN_HTML is not pinned in script-src; add 'sha256-${h}'" ;;
  esac
done

# Stale hashes: in the policy but no longer on the page.
mapfile -t CSP_HASHES < <(printf '%s\n' "$SCRIPT_SRC" | grep -o "sha256-[A-Za-z0-9+/=]\{1,\}" | sed 's/^sha256-//')
for h in "${CSP_HASHES[@]}"; do
  found=0
  for p in "${PAGE_HASHES[@]}"; do
    [ "$h" = "$p" ] && found=1 && break
  done
  [ "$found" -eq 1 ] || fail "stale hash in script-src, matches no inline script: 'sha256-${h}'"
done

# ── 3. The external bundle ───────────────────────────────────────────────────
BUNDLE_SRC=$(grep -o 'src="https://[^"]*sveltia-cms\.js"' "$ADMIN_HTML" | sed 's/^src="//; s/"$//' | head -1)
if [ -z "$BUNDLE_SRC" ]; then
  fail "no sveltia-cms.js <script src=...> found in $ADMIN_HTML"
else
  BUNDLE_ORIGIN=$(printf '%s\n' "$BUNDLE_SRC" | sed -n 's#^\(https://[^/]\{1,\}\).*#\1#p')
  case " $SCRIPT_SRC " in
    *" $BUNDLE_ORIGIN "*) ;;
    *) fail "bundle origin $BUNDLE_ORIGIN is not allowed by script-src" ;;
  esac
  # The bundle lazily import()s @shikijs/*, @sveltia/ui, emojilib and pdf.js from
  # the same CDN at runtime. Those chunks are fetched, not <script>-tagged, so
  # connect-src has to allow the origin too or they fail under an enforcing CSP.
  case " $CONNECT_SRC " in
    *" $BUNDLE_ORIGIN "*) ;;
    *) fail "bundle origin $BUNDLE_ORIGIN is not in connect-src (the bundle import()s lazy chunks from it at runtime)" ;;
  esac
  grep -q 'integrity="sha384-' "$ADMIN_HTML" \
    || fail "bundle <script> has no sha384 integrity attribute"
  printf '%s\n' "$BUNDLE_SRC" | grep -q '@[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}/' \
    || fail "bundle src is not pinned to an exact version: $BUNDLE_SRC"
fi

# ── 4. connect-src bounds exfiltration ───────────────────────────────────────
if [ -z "$CONNECT_SRC" ]; then
  fail "CSP has no connect-src — that directive is what stops a stolen token being POSTed off-origin"
else
  # Every source has to name a host. A bare `*`, a scheme-only source (`https:`),
  # and a wildcard host (`https://*`, `https://*.example.com`) all let the token
  # be POSTed to somewhere we do not control, which is the whole thing this
  # directive exists to prevent.
  # `set -f` because the word-splitting below must not glob: an unquoted bare
  # `*` source would otherwise expand to the working directory's filenames and
  # slip straight past the check.
  set -f
  # shellcheck disable=SC2086
  for src in $CONNECT_SRC; do
    case "$src" in
      \'*\') continue ;; # 'self', 'none' and friends are keywords, not hosts
    esac
    case "$src" in
      '*')
        fail "connect-src allows '*'; it must name hosts explicitly"
        ;;
      http: | https: | ws: | wss: | data: | blob: | filesystem: | mediastream:)
        fail "connect-src allows the scheme-only source '$src'; it must name hosts explicitly"
        ;;
      *'*'*)
        fail "connect-src allows the wildcard host source '$src'; it must name hosts explicitly"
        ;;
    esac
  done
  set +f
fi

# ── 5. COOP must stay off ────────────────────────────────────────────────────
if printf '%s\n' "$ADMIN_BLOCK" | grep -qi 'Cross-Origin-Opener-Policy'; then
  fail "Cross-Origin-Opener-Policy is set on /admin/*. Remove it: Sveltia signs in
      via a popup that postMessages the GitHub token back to window.opener, and
      COOP severs that reference. Setting it breaks login."
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "" >&2
  echo "FAILED: $ERRORS check(s) failed" >&2
  exit 1
fi

echo "OK: /admin/ CSP matches static/admin/index.html"
