#!/usr/bin/env bash
#
# Install this repo's pinned developer tools into .tools/bin, on first use.
#
# Every check target in the Makefile depends on one of these, so a fresh
# checkout — a new laptop, a git worktree, an agent session on a sandbox VM —
# can run `make check` without a single manual install step. Before this
# existed the Makefile printed `brew install <tool>` and exited 1, which is a
# dead end on any machine without Homebrew, i.e. every Linux CI runner and
# every sandbox.
#
# Versions come from tools.mk (and .hugo-version for hugo), which CI reads
# too, so the binary that produced a passing local run is the same build CI
# runs. .tools/bin is PREPENDED to PATH by the Makefile, so the pin wins over
# a brew- or apt-installed copy; the shadowing is announced rather than silent.
#
# Downloads are release assets over HTTPS. Where a project publishes a
# checksums file (hugo, actionlint, vale) the asset is verified against it.
# shfmt, shellcheck and lychee publish none — noted per-tool below rather
# than silently skipped.
#
# Usage:
#   scripts/ensure-tool.sh <tool>...
#   scripts/ensure-tool.sh shfmt shellcheck
#
# Tools: hugo shfmt shellcheck actionlint vale lychee
#
# Tunables (env):
#   TOOLS_DIR        install root (default: <repo>/.tools)
#   TOOLS_OFFLINE    1 = never download; fail with the manual install command
#   TOOLS_FETCH_CMD  fetch shim for tests, called as: CMD <url> <dest-file>
#   TOOLS_UNAME_S    override the detected OS   (test seam; e.g. Darwin)
#   TOOLS_UNAME_M    override the detected arch (test seam; e.g. arm64)
#   TOOLS_PKGUTIL_CMD  pkgutil shim for tests (default: pkgutil)
#
# The last three exist so a Linux runner can cover the macOS asset mapping and
# the .pkg extraction path. Without them those branches only ever run on a
# contributor's laptop, which is exactly where a wrong asset name would go
# unnoticed until someone tried to bootstrap.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${TOOLS_DIR:-$REPO_ROOT/.tools}"
BIN_DIR="$TOOLS_DIR/bin"
STAMP_DIR="$TOOLS_DIR/stamps"

: "${TOOLS_OFFLINE:=0}"
: "${TOOLS_FETCH_CMD:=}"
: "${TOOLS_UNAME_S:=$(uname -s)}"
: "${TOOLS_UNAME_M:=$(uname -m)}"
: "${TOOLS_PKGUTIL_CMD:=pkgutil}"

SUPPORTED_TOOLS="hugo shfmt shellcheck actionlint vale lychee"

die() {
  echo "❌ ensure-tool: $*" >&2
  exit 1
}

# ── Version lookup ────────────────────────────────────────────────────────────
# hugo is the one pin that does not live in tools.mk; see that file's header.

tool_version() {
  local tool="$1"

  if [ "$tool" = hugo ]; then
    local v
    v="$(tr -d '[:space:]' <"$REPO_ROOT/.hugo-version" 2>/dev/null || true)"
    [ -n "$v" ] || die "no version in .hugo-version"
    echo "$v"
    return
  fi

  # tools.mk is plain KEY=value, so bash can source what Make includes.
  # shellcheck source=tools.mk
  source "$REPO_ROOT/tools.mk"

  case "$tool" in
    shfmt) echo "$SHFMT_VERSION" ;;
    shellcheck) echo "$SHELLCHECK_VERSION" ;;
    actionlint) echo "$ACTIONLINT_VERSION" ;;
    vale) echo "$VALE_VERSION" ;;
    lychee) echo "$LYCHEE_VERSION" ;;
    *) die "unknown tool '$tool' (supported: $SUPPORTED_TOOLS)" ;;
  esac
}

# ── Asset resolution ──────────────────────────────────────────────────────────
# Sets ASSET_URL, ARCHIVE_KIND and CHECKSUMS_URL for <tool> at <version> on
# this platform. No two of these projects name their assets the same way, so
# the mapping is spelled out per tool rather than templated.
#
# ARCHIVE_KIND is one of: raw (a bare binary), tar.gz, tar.xz, pkg.
# The extracted binary is always found by name, so nested archive layouts
# (shellcheck ships its binary under shellcheck-vX/) need no special case.

resolve_asset() {
  local tool="$1" v="$2"
  local os arch

  case "$TOOLS_UNAME_S" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) die "unsupported OS: $TOOLS_UNAME_S. Install $tool $v manually." ;;
  esac

  case "$TOOLS_UNAME_M" in
    x86_64 | amd64) arch=amd64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) die "unsupported architecture: $TOOLS_UNAME_M. Install $tool $v manually." ;;
  esac

  ASSET_URL=""
  ARCHIVE_KIND=""
  CHECKSUMS_URL=""

  case "$tool" in
    shfmt)
      # A bare static binary, not an archive. No checksums file published.
      ASSET_URL="https://github.com/mvdan/sh/releases/download/v$v/shfmt_v${v}_${os}_${arch}"
      ARCHIVE_KIND=raw
      ;;

    shellcheck)
      # uname-style arch names, and xz rather than gzip. No checksums file.
      local sc_arch=x86_64
      [ "$arch" = arm64 ] && sc_arch=aarch64
      ASSET_URL="https://github.com/koalaman/shellcheck/releases/download/v$v/shellcheck-v$v.${os}.${sc_arch}.tar.xz"
      ARCHIVE_KIND=tar.xz
      ;;

    actionlint)
      local base="https://github.com/rhysd/actionlint/releases/download/v$v"
      ASSET_URL="$base/actionlint_${v}_${os}_${arch}.tar.gz"
      ARCHIVE_KIND=tar.gz
      CHECKSUMS_URL="$base/actionlint_${v}_checksums.txt"
      ;;

    vale)
      # Vale's own spelling: Linux_64-bit, Linux_arm64, macOS_64-bit, macOS_arm64.
      local vale_os vale_arch
      case "$os" in
        linux) vale_os=Linux ;;
        darwin) vale_os=macOS ;;
      esac
      case "$arch" in
        amd64) vale_arch=64-bit ;;
        arm64) vale_arch=arm64 ;;
      esac
      local base="https://github.com/errata-ai/vale/releases/download/v$v"
      ASSET_URL="$base/vale_${v}_${vale_os}_${vale_arch}.tar.gz"
      ARCHIVE_KIND=tar.gz
      CHECKSUMS_URL="$base/vale_${v}_checksums.txt"
      ;;

    lychee)
      # Rust target triples on Linux, a shorter <arch>-macos on darwin, and
      # the tag is lychee-vX rather than vX. No checksums file published.
      local target
      case "$os-$arch" in
        linux-amd64) target=x86_64-unknown-linux-gnu ;;
        linux-arm64) target=aarch64-unknown-linux-gnu ;;
        darwin-arm64) target=arm64-macos ;;
        darwin-amd64) die "lychee publishes no x86_64 macOS build. Install it with: brew install lychee" ;;
      esac
      ASSET_URL="https://github.com/lycheeverse/lychee/releases/download/lychee-v$v/lychee-${target}.tar.gz"
      ARCHIVE_KIND=tar.gz
      ;;

    hugo)
      # Extended, always: CI uses peaceiris/actions-hugo with extended: true
      # and Netlify builds extended too. The old `go install` path here built
      # the STANDARD binary, which has no WebP or libsass — so covers were
      # processed differently locally than in CI, and scripts/check-image-sizes.sh
      # could pass on one and fail on the other.
      #
      # macOS gets a .pkg because Hugo publishes no darwin tarball at all
      # (the release ships hugo_extended_<v>_darwin-universal.pkg only).
      local base="https://github.com/gohugoio/hugo/releases/download/v$v"
      if [ "$os" = darwin ]; then
        ASSET_URL="$base/hugo_extended_${v}_darwin-universal.pkg"
        ARCHIVE_KIND=pkg
      else
        ASSET_URL="$base/hugo_extended_${v}_linux-${arch}.tar.gz"
        ARCHIVE_KIND=tar.gz
      fi
      # One checksums file covers every asset in the release, extended included.
      CHECKSUMS_URL="$base/hugo_${v}_checksums.txt"
      ;;

    *)
      die "unknown tool '$tool' (supported: $SUPPORTED_TOOLS)"
      ;;
  esac
}

# ── Download, verify, extract ─────────────────────────────────────────────────

fetch() { # <url> <dest>
  if [ -n "$TOOLS_FETCH_CMD" ]; then
    "$TOOLS_FETCH_CMD" "$1" "$2"
    return
  fi
  curl --fail --silent --show-error --location \
    --proto '=https' --tlsv1.2 \
    --retry 3 --retry-delay 2 --max-time 300 \
    --output "$2" "$1"
}

sha256_of() { # <file>
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    # macOS has no sha256sum in the base system.
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

verify_checksum() { # <file> <checksums-url> <asset-basename>
  local file="$1" url="$2" name="$3" sums expected actual

  sums="$(mktemp)"
  if ! fetch "$url" "$sums"; then
    rm -f "$sums"
    die "could not fetch checksums from $url"
  fi

  expected="$(awk -v n="$name" '$2 == n || $2 == "*" n {print $1; exit}' "$sums")"
  rm -f "$sums"

  [ -n "$expected" ] || die "$name is not listed in $url"

  actual="$(sha256_of "$file")"
  [ "$actual" = "$expected" ] \
    || die "checksum mismatch for $name (expected $expected, got $actual)"
}

extract_binary() { # <archive> <kind> <tool> <workdir> -> prints path to binary
  local archive="$1" kind="$2" tool="$3" work="$4" found

  case "$kind" in
    raw)
      echo "$archive"
      return
      ;;
    tar.gz) tar -xzf "$archive" -C "$work" ;;
    tar.xz) tar -xJf "$archive" -C "$work" ;;
    pkg)
      # A macOS .pkg is an xar archive; pkgutil is a base-system tool.
      command -v "$TOOLS_PKGUTIL_CMD" >/dev/null 2>&1 \
        || die "$TOOLS_PKGUTIL_CMD not found — cannot unpack $tool's macOS .pkg"
      "$TOOLS_PKGUTIL_CMD" --expand-full "$archive" "$work/pkg" \
        || die "could not expand $tool's .pkg"
      ;;
    *) die "internal error: unknown archive kind '$kind'" ;;
  esac

  # Find by name rather than by a hard-coded path inside the archive: the
  # layouts differ per project (shellcheck nests under shellcheck-vX/, the
  # .pkg buries it under a Payload tree) and they change between releases.
  found="$(find "$work" -type f -name "$tool" -print -quit 2>/dev/null || true)"
  [ -n "$found" ] || die "no '$tool' binary inside $(basename "$archive")"
  echo "$found"
}

# ── Per-tool install ──────────────────────────────────────────────────────────

ensure_one() {
  local tool="$1" version stamp work archive binary shadowed

  case " $SUPPORTED_TOOLS " in
    *" $tool "*) ;;
    *) die "unknown tool '$tool' (supported: $SUPPORTED_TOOLS)" ;;
  esac

  version="$(tool_version "$tool")"
  stamp="$STAMP_DIR/$tool-$version"

  # A stamp rather than running `<tool> --version`: a warm `make check` hits
  # this path once per tool and should cost a stat, not six process spawns.
  if [ -f "$stamp" ] && [ -x "$BIN_DIR/$tool" ]; then
    echo "✅ $tool $version"
    return
  fi

  resolve_asset "$tool" "$version"

  if [ "$TOOLS_OFFLINE" = "1" ]; then
    die "$tool $version is not installed and TOOLS_OFFLINE=1.
   Fetch it by hand from: $ASSET_URL
   and place the binary at: $BIN_DIR/$tool"
  fi

  echo "➡️  Installing $tool $version"

  work="$(mktemp -d)"
  # shellcheck disable=SC2064  # expand $work now: it is what we want removed.
  trap "rm -rf '$work'" RETURN

  archive="$work/$(basename "$ASSET_URL")"
  fetch "$ASSET_URL" "$archive" || die "download failed: $ASSET_URL"

  if [ -n "$CHECKSUMS_URL" ]; then
    verify_checksum "$archive" "$CHECKSUMS_URL" "$(basename "$ASSET_URL")"
  fi

  binary="$(extract_binary "$archive" "$ARCHIVE_KIND" "$tool" "$work")"

  mkdir -p "$BIN_DIR" "$STAMP_DIR"
  install -m 0755 "$binary" "$BIN_DIR/$tool"

  # Old stamps for this tool are stale the moment the pin moves.
  rm -f "$STAMP_DIR/$tool"-*
  : >"$stamp"

  # Say so when we are shadowing something, so a version difference between
  # `make lint` and a bare `shellcheck` in the same shell is never a mystery.
  shadowed="$(PATH="${PATH//$BIN_DIR:/}" command -v "$tool" 2>/dev/null || true)"
  if [ -n "$shadowed" ] && [ "$shadowed" != "$BIN_DIR/$tool" ]; then
    echo "   note: shadows $shadowed (this repo pins $tool $version)"
  fi

  echo "✅ $tool $version"
}

# ── Main ──────────────────────────────────────────────────────────────────────

if [ "$#" -eq 0 ]; then
  echo "Usage: scripts/ensure-tool.sh <tool>..." >&2
  echo "Tools: $SUPPORTED_TOOLS" >&2
  exit 64
fi

for requested in "$@"; do
  ensure_one "$requested"
done
