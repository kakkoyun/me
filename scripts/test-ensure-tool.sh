#!/usr/bin/env bash
# Unit tests for scripts/ensure-tool.sh
#
# Self-contained and offline: every download is stubbed via TOOLS_FETCH_CMD, so
# no network is touched and no real binary is fetched. Each case installs into
# its own throwaway TOOLS_DIR. No external test framework required.
#
# Usage: bash scripts/test-ensure-tool.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENSURE_SCRIPT="$REPO_ROOT/scripts/ensure-tool.sh"

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

assert_contains() {
  if [[ "$3" == *"$2"* ]]; then pass "$1"; else fail "$1" "*$2*" "$3"; fi
}

assert_executable() { # <label> <path>
  if [ -x "$2" ]; then pass "$1"; else fail "$1" "executable $2" "missing"; fi
}

assert_absent() { # <label> <path>
  if [ -e "$2" ]; then fail "$1" "nothing at $2" "file present"; else pass "$1"; fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── Fetch stubs ───────────────────────────────────────────────────────────────
# A stub receives <url> <dest> and must create <dest>. They append the URL to
# $URL_LOG so tests can assert on what would have been downloaded.

# Records the URL and produces an archive containing the requested binary, so
# the download → verify → extract → install path runs end to end offline. When
# the installer then asks for a checksums file, the stub computes the real
# digest of the archive it just produced, so checksum verification is exercised
# rather than bypassed. Set STUB_CORRUPT=1 to emit a wrong digest instead.
cat >"$TMP/fetch-tar.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
url="$1"
dest="$2"
[ -n "${URL_LOG:-}" ] && echo "$url" >>"$URL_LOG"

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Serve a checksums file for the archive produced by the preceding call.
case "$url" in
  *checksums.txt)
    [ -f "${STUB_STATE:?STUB_STATE unset}" ] || {
      echo "checksums requested before any asset" >&2
      exit 1
    }
    read -r archive name <"$STUB_STATE"
    if [ "${STUB_CORRUPT:-0}" = "1" ]; then
      printf '%s  %s\n' "0000000000000000000000000000000000000000000000000000000000000000" "$name"
    else
      printf '%s  %s\n' "$(sha_of "$archive")" "$name"
    fi >"$dest"
    exit 0
    ;;
esac

work=$(mktemp -d)
case "$url" in
  *shfmt*) name=shfmt ;;
  *shellcheck*) name=shellcheck ;;
  *actionlint*) name=actionlint ;;
  *vale*) name=vale ;;
  *lychee*) name=lychee ;;
  *hugo*) name=hugo ;;
  *) name=unknown ;;
esac

case "$url" in
  *.tar.gz)
    printf '#!/bin/sh\necho stub-%s\n' "$name" >"$work/$name"
    chmod +x "$work/$name"
    tar -czf "$dest" -C "$work" "$name"
    ;;
  *.tar.xz)
    # Mirror shellcheck's nested layout to prove the finder is not path-bound.
    mkdir -p "$work/shellcheck-v0.0.0"
    printf '#!/bin/sh\necho stub-%s\n' "$name" >"$work/shellcheck-v0.0.0/$name"
    chmod +x "$work/shellcheck-v0.0.0/$name"
    tar -cJf "$dest" -C "$work" "shellcheck-v0.0.0"
    ;;
  *)
    # Raw binary (shfmt).
    printf '#!/bin/sh\necho stub-%s\n' "$name" >"$dest"
    ;;
esac
rm -rf "$work"

# Remember what we produced, for a checksums request that follows.
[ -n "${STUB_STATE:-}" ] && printf '%s %s\n' "$dest" "$(basename "$url")" >"$STUB_STATE"
exit 0
EOF
chmod +x "$TMP/fetch-tar.sh"

# Always fails, to exercise the download-error path.
cat >"$TMP/fetch-fail.sh" <<'EOF'
#!/usr/bin/env bash
exit 22
EOF
chmod +x "$TMP/fetch-fail.sh"

run_ensure() { # <tools-dir> <tool>... -> prints combined output, never fails
  local dir="$1"
  shift
  TOOLS_DIR="$dir" TOOLS_FETCH_CMD="$TMP/fetch-tar.sh" \
    STUB_STATE="$TMP/stub-state" URL_LOG="${URL_LOG:-}" \
    bash "$ENSURE_SCRIPT" "$@" 2>&1 || true
}

echo "── ensure-tool.sh ──────────────────────────────────────────────────────"

# ── Argument handling ─────────────────────────────────────────────────────────
out=$(bash "$ENSURE_SCRIPT" 2>&1 || true)
assert_contains "no arguments prints usage" "Usage: scripts/ensure-tool.sh" "$out"

rc=0
bash "$ENSURE_SCRIPT" >/dev/null 2>&1 || rc=$?
assert_eq "no arguments exits 64 (EX_USAGE)" "64" "$rc"

out=$(bash "$ENSURE_SCRIPT" definitely-not-a-tool 2>&1 || true)
assert_contains "unknown tool is rejected" "unknown tool 'definitely-not-a-tool'" "$out"

rc=0
bash "$ENSURE_SCRIPT" definitely-not-a-tool >/dev/null 2>&1 || rc=$?
assert_eq "unknown tool exits 1" "1" "$rc"

# ── Install, from a raw binary and from archives ──────────────────────────────
d="$TMP/install-raw"
out=$(run_ensure "$d" shfmt)
assert_contains "shfmt reports its pinned version" "shfmt" "$out"
assert_executable "shfmt binary is installed executable" "$d/bin/shfmt"

d="$TMP/install-targz"
run_ensure "$d" vale >/dev/null
assert_executable "tar.gz payload is extracted and installed" "$d/bin/vale"

# The real shellcheck tarball nests its binary inside shellcheck-vX/, so this
# proves the installer finds it by name rather than by a hard-coded path.
d="$TMP/install-tarxz"
run_ensure "$d" shellcheck >/dev/null
assert_executable "nested tar.xz payload is found by name" "$d/bin/shellcheck"

# ── Stamps ────────────────────────────────────────────────────────────────────
d="$TMP/stamps"
run_ensure "$d" vale >/dev/null
stamp_count=$(find "$d/stamps" -name 'vale-*' | wc -l | tr -d ' ')
assert_eq "one stamp is written per tool" "1" "$stamp_count"

out=$(run_ensure "$d" vale)
assert_contains "a stamped tool is not re-downloaded" "✅ vale" "$out"
if [[ "$out" == *"Installing"* ]]; then
  fail "a stamped tool is not re-downloaded" "no 'Installing' line" "$out"
else
  pass "warm run skips the download"
fi

# A stamp without the binary must not count as installed.
rm -f "$d/bin/vale"
out=$(run_ensure "$d" vale)
assert_contains "a missing binary reinstalls despite the stamp" "Installing" "$out"

# ── Offline mode ──────────────────────────────────────────────────────────────
d="$TMP/offline"
out=$(TOOLS_DIR="$d" TOOLS_OFFLINE=1 bash "$ENSURE_SCRIPT" shfmt 2>&1 || true)
assert_contains "offline mode refuses to download" "TOOLS_OFFLINE=1" "$out"
assert_contains "offline mode names the asset URL" "https://github.com/mvdan/sh/releases" "$out"

rc=0
TOOLS_DIR="$d" TOOLS_OFFLINE=1 bash "$ENSURE_SCRIPT" shfmt >/dev/null 2>&1 || rc=$?
assert_eq "offline mode exits 1" "1" "$rc"

# ── Download failure ──────────────────────────────────────────────────────────
d="$TMP/dlfail"
rc=0
TOOLS_DIR="$d" TOOLS_FETCH_CMD="$TMP/fetch-fail.sh" \
  bash "$ENSURE_SCRIPT" vale >/dev/null 2>&1 || rc=$?
assert_eq "a failed download exits 1" "1" "$rc"
assert_absent "a failed download installs nothing" "$d/bin/vale"

# ── URL construction ──────────────────────────────────────────────────────────
# The pinned version must appear in the URL actually requested, for every tool.
# This is what catches a tools.mk rename or a bad asset-name template.
# shellcheck source=tools.mk
source "$REPO_ROOT/tools.mk"
hugo_version=$(tr -d '[:space:]' <"$REPO_ROOT/.hugo-version")

check_url() { # <tool> <expected-substring>
  # Separate `local` statements on purpose: bash expands every argument of a
  # single `local` before assigning any of them, so `log="$TMP/url-$tool.log"`
  # on the same line would read an unset $tool and trip `set -u`.
  local tool="$1"
  local want="$2"
  local log="$TMP/url-$tool.log"
  local got
  : >"$log"
  URL_LOG="$log" TOOLS_DIR="$TMP/urls-$tool" TOOLS_FETCH_CMD="$TMP/fetch-tar.sh" \
    STUB_STATE="$TMP/stub-state" \
    bash "$ENSURE_SCRIPT" "$tool" >/dev/null 2>&1 || true
  got=$(head -1 "$log" 2>/dev/null || true)
  assert_contains "$tool asset URL carries its pin" "$want" "$got"
}

check_url shfmt "shfmt_v${SHFMT_VERSION}_"
check_url shellcheck "shellcheck-v${SHELLCHECK_VERSION}."
check_url actionlint "actionlint_${ACTIONLINT_VERSION}_"
check_url vale "vale_${VALE_VERSION}_"
# lychee tags releases lychee-vX rather than vX.
check_url lychee "lychee-v${LYCHEE_VERSION}/"
# Hugo must be the EXTENDED build, at the .hugo-version pin.
check_url hugo "hugo_extended_${hugo_version}_"

# ── Cross-platform asset mapping ───────────────────────────────────────────────
# The host here is always Linux, so without the TOOLS_UNAME_* seams the macOS
# branches would only ever run on a contributor's laptop — the one place a wrong
# asset name goes unnoticed until someone tries to bootstrap. Each expectation
# below is a real published asset name.

url_on() { # <os> <arch> <tool> -> prints the URL that would be fetched
  local os="$1"
  local arch="$2"
  local tool="$3"
  local dir="$TMP/x-$os-$arch-$tool"
  TOOLS_UNAME_S="$os" TOOLS_UNAME_M="$arch" TOOLS_DIR="$dir" TOOLS_OFFLINE=1 \
    bash "$ENSURE_SCRIPT" "$tool" 2>&1 | sed -n 's/.*Fetch it by hand from: //p' | head -1
}

check_url_on() { # <os> <arch> <tool> <expected-substring>
  local os="$1"
  local arch="$2"
  local tool="$3"
  local want="$4"
  assert_contains "$tool on $os/$arch" "$want" "$(url_on "$os" "$arch" "$tool")"
}

# macOS arm64 — the maintainer's own machine.
check_url_on Darwin arm64 shfmt "shfmt_v${SHFMT_VERSION}_darwin_arm64"
check_url_on Darwin arm64 shellcheck "shellcheck-v${SHELLCHECK_VERSION}.darwin.aarch64.tar.xz"
check_url_on Darwin arm64 actionlint "actionlint_${ACTIONLINT_VERSION}_darwin_arm64.tar.gz"
check_url_on Darwin arm64 vale "vale_${VALE_VERSION}_macOS_arm64.tar.gz"
check_url_on Darwin arm64 lychee "lychee-arm64-macos.tar.gz"
# Hugo publishes no darwin tarball at all — only a universal .pkg.
check_url_on Darwin arm64 hugo "hugo_extended_${hugo_version}_darwin-universal.pkg"

# macOS x86_64 — Vale spells it differently again.
check_url_on Darwin x86_64 vale "vale_${VALE_VERSION}_macOS_64-bit.tar.gz"
check_url_on Darwin x86_64 shellcheck "shellcheck-v${SHELLCHECK_VERSION}.darwin.x86_64.tar.xz"

# Linux arm64, for anyone on an arm runner or a Raspberry Pi.
check_url_on Linux aarch64 vale "vale_${VALE_VERSION}_Linux_arm64.tar.gz"
check_url_on Linux aarch64 hugo "hugo_extended_${hugo_version}_linux-arm64.tar.gz"
check_url_on Linux aarch64 lychee "lychee-aarch64-unknown-linux-gnu.tar.gz"

# lychee ships no x86_64 macOS build. Say so plainly rather than 404ing.
out=$(TOOLS_UNAME_S=Darwin TOOLS_UNAME_M=x86_64 TOOLS_DIR="$TMP/no-lychee" \
  bash "$ENSURE_SCRIPT" lychee 2>&1 || true)
assert_contains "lychee on Darwin/x86_64 explains itself" "no x86_64 macOS build" "$out"

# An unknown platform must not silently build a nonsense URL.
out=$(TOOLS_UNAME_S=Plan9 TOOLS_DIR="$TMP/plan9" bash "$ENSURE_SCRIPT" shfmt 2>&1 || true)
assert_contains "an unsupported OS is rejected" "unsupported OS: Plan9" "$out"
out=$(TOOLS_UNAME_M=s390x TOOLS_DIR="$TMP/s390x" bash "$ENSURE_SCRIPT" shfmt 2>&1 || true)
assert_contains "an unsupported architecture is rejected" "unsupported architecture: s390x" "$out"

# ── macOS .pkg extraction ─────────────────────────────────────────────────────
# Hugo on macOS arrives as a .pkg, which is unpacked with pkgutil and buries the
# binary under a Payload tree. Stub pkgutil so the branch runs on Linux.
cat >"$TMP/pkgutil-stub.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Usage mirrors: pkgutil --expand-full <archive> <dest>
dest="$3"
mkdir -p "$dest/hugo.pkg/Payload/usr/local/bin"
printf '#!/bin/sh\necho stub-hugo\n' >"$dest/hugo.pkg/Payload/usr/local/bin/hugo"
chmod +x "$dest/hugo.pkg/Payload/usr/local/bin/hugo"
EOF
chmod +x "$TMP/pkgutil-stub.sh"

d="$TMP/darwin-pkg"
TOOLS_UNAME_S=Darwin TOOLS_UNAME_M=arm64 TOOLS_DIR="$d" \
  TOOLS_FETCH_CMD="$TMP/fetch-tar.sh" STUB_STATE="$TMP/stub-state" \
  TOOLS_PKGUTIL_CMD="$TMP/pkgutil-stub.sh" \
  bash "$ENSURE_SCRIPT" hugo >/dev/null 2>&1 || true
assert_executable "hugo is extracted from a macOS .pkg" "$d/bin/hugo"

# Without pkgutil the failure has to be legible, not a confusing 'not found'.
out=$(TOOLS_UNAME_S=Darwin TOOLS_UNAME_M=arm64 TOOLS_DIR="$TMP/nopkgutil" \
  TOOLS_FETCH_CMD="$TMP/fetch-tar.sh" STUB_STATE="$TMP/stub-state" \
  TOOLS_PKGUTIL_CMD=definitely-not-pkgutil \
  bash "$ENSURE_SCRIPT" hugo 2>&1 || true)
assert_contains "a missing pkgutil is reported clearly" "cannot unpack" "$out"

# ── Checksum verification ─────────────────────────────────────────────────────
# vale, actionlint and hugo publish a checksums file, and the installer must
# refuse an asset whose digest does not match it.
d="$TMP/checksum-bad"
rc=0
TOOLS_DIR="$d" TOOLS_FETCH_CMD="$TMP/fetch-tar.sh" STUB_STATE="$TMP/stub-state" \
  STUB_CORRUPT=1 bash "$ENSURE_SCRIPT" vale >/dev/null 2>&1 || rc=$?
assert_eq "a checksum mismatch exits 1" "1" "$rc"
assert_absent "a checksum mismatch installs nothing" "$d/bin/vale"

out=$(TOOLS_DIR="$TMP/checksum-bad2" TOOLS_FETCH_CMD="$TMP/fetch-tar.sh" \
  STUB_STATE="$TMP/stub-state" STUB_CORRUPT=1 \
  bash "$ENSURE_SCRIPT" vale 2>&1 || true)
assert_contains "a checksum mismatch says so" "checksum mismatch" "$out"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "  ${PASS} passed, ${FAIL} failed"
if ((FAIL > 0)); then
  exit 1
fi
