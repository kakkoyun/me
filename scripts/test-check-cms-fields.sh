#!/usr/bin/env bash
# Unit tests for scripts/check-cms-fields.sh
#
# Self-contained: each case builds isolated fixture directories and a minimal
# CMS config. No git, no network, no framework.
#
# Usage: bash scripts/test-check-cms-fields.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-cms-fields.sh"

PASS=0
FAIL=0
pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; (( PASS += 1 )); }
fail() {
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
  printf "         expected exit: %s\n" "${2:-<empty>}"
  printf "         actual exit:   %s\n" "${3:-<empty>}"
  (( FAIL += 1 ))
}
assert_exit() {
  local label="$1" want="$2" got=0
  shift 2
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$want" = "$got" ]; then pass "$label"; else fail "$label" "$want" "$got"; fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

make_config() {
  # make_config <field> [<field2> ...]
  local dir="$TMP/static/admin"
  mkdir -p "$dir"
  {
    echo "collections:"
    echo "  - name: posts"
    echo "    folder: content/posts"
    echo "    fields:"
    for f in "$@"; do
      echo "      - name: $f"
      echo "        widget: string"
    done
  } > "$dir/config.yml"
}

make_post() {
  # make_post <filename> <key> [<key2> ...]
  local posts_dir="$TMP/content/posts"
  mkdir -p "$posts_dir"
  local file="$posts_dir/$1"
  shift
  {
    echo "---"
    for k in "$@"; do
      echo "$k: value"
    done
    echo "---"
    echo "body"
  } > "$file"
}

run() {
  CMS_CONFIG="$TMP/static/admin/config.yml" \
  CMS_CONTENT_DIRS="$TMP/content/posts" \
  bash "$SCRIPT"
}

cleanup() {
  rm -rf "$TMP/static" "$TMP/content"
}

echo "── check-cms-fields ────────────────────────────────────"

# All keys declared → exits 0.
cleanup
make_config title description date
make_post p1.md title description date
assert_exit "all keys declared exits 0" 0 \
  env CMS_CONFIG="$TMP/static/admin/config.yml" CMS_CONTENT_DIRS="$TMP/content/posts" bash "$SCRIPT"

# Undeclared key → exits 1.
cleanup
make_config title description
make_post p1.md title description promote
assert_exit "undeclared key exits 1" 1 \
  env CMS_CONFIG="$TMP/static/admin/config.yml" CMS_CONTENT_DIRS="$TMP/content/posts" bash "$SCRIPT"

# Missing config → exits 1.
cleanup
mkdir -p "$TMP/content/posts"
assert_exit "missing config exits 1" 1 \
  env CMS_CONFIG="$TMP/static/admin/config.yml" CMS_CONTENT_DIRS="$TMP/content/posts" bash "$SCRIPT"

# Empty posts directory → exits 0.
cleanup
make_config title
mkdir -p "$TMP/content/posts"
assert_exit "empty posts dir exits 0" 0 \
  env CMS_CONFIG="$TMP/static/admin/config.yml" CMS_CONTENT_DIRS="$TMP/content/posts" bash "$SCRIPT"

# Multiple posts, all keys declared → exits 0.
cleanup
make_config title tags date
make_post p1.md title date
make_post p2.md title tags
assert_exit "multiple posts all declared exits 0" 0 \
  env CMS_CONFIG="$TMP/static/admin/config.yml" CMS_CONTENT_DIRS="$TMP/content/posts" bash "$SCRIPT"

# Key in second post undeclared → exits 1.
cleanup
make_config title date
make_post p1.md title date
make_post p2.md title date substack
assert_exit "undeclared key in second post exits 1" 1 \
  env CMS_CONFIG="$TMP/static/admin/config.yml" CMS_CONTENT_DIRS="$TMP/content/posts" bash "$SCRIPT"

echo
echo "$((PASS + FAIL)) tests run — $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
