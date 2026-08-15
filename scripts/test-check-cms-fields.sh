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

CONFIG="$TMP/static/admin/config.yml"

begin_config() {
  mkdir -p "$(dirname "$CONFIG")"
  echo "collections:" > "$CONFIG"
}

add_collection() {
  # add_collection <name> <folder> [<field> ...]
  local name="$1" folder="$2"
  shift 2
  {
    echo "  - name: $name"
    echo "    folder: $folder"
    echo "    fields:"
    for f in "$@"; do
      echo "      - name: $f"
      echo "        widget: string"
    done
  } >> "$CONFIG"
}

make_config() {
  # make_config <field> [<field2> ...] — single posts collection, the common case.
  begin_config
  add_collection posts content/posts "$@"
}

make_config_nested() {
  # make_config_nested <object-field> <nested-field> [<nested-field2> ...]
  # A collection whose only field is an object with nested fields, at the same
  # indentation the real config.yml uses.
  local obj="$1"
  shift
  begin_config
  {
    echo "  - name: posts"
    echo "    folder: content/posts"
    echo "    fields:"
    echo "      - label: Object"
    echo "        name: $obj"
    echo "        widget: object"
    echo "        fields:"
    for f in "$@"; do
      echo "          - label: Nested"
      echo "            name: $f"
      echo "            widget: string"
    done
  } >> "$CONFIG"
}

make_entry() {
  # make_entry <folder> <filename> [<key> ...]
  local dir="$TMP/$1" file
  mkdir -p "$dir"
  file="$dir/$2"
  shift 2
  {
    echo "---"
    for k in "$@"; do
      echo "$k: value"
    done
    echo "---"
    echo "body"
  } > "$file"
}

make_post() {
  # make_post <filename> [<key> ...]
  local name="$1"
  shift
  make_entry content/posts "$name" "$@"
}

run() {
  # run <label> <expected-exit>
  assert_exit "$1" "$2" \
    env CMS_CONFIG="$CONFIG" CMS_CONTENT_ROOT="$TMP" bash "$SCRIPT"
}

cleanup() {
  rm -rf "$TMP/static" "$TMP/content"
}

echo "── check-cms-fields ────────────────────────────────────"

# All keys declared → exits 0.
cleanup
make_config title description date
make_post p1.md title description date
run "all keys declared exits 0" 0

# Undeclared key → exits 1.
cleanup
make_config title description
make_post p1.md title description promote
run "undeclared key exits 1" 1

# Missing config → exits 1.
cleanup
mkdir -p "$TMP/content/posts"
run "missing config exits 1" 1

# Empty posts directory → exits 0.
cleanup
make_config title
mkdir -p "$TMP/content/posts"
run "empty posts dir exits 0" 0

# Multiple posts, all keys declared → exits 0.
cleanup
make_config title tags date
make_post p1.md title date
make_post p2.md title tags
run "multiple posts all declared exits 0" 0

# Key in second post undeclared → exits 1.
cleanup
make_config title date
make_post p1.md title date
make_post p2.md title date substack
run "undeclared key in second post exits 1" 1

# A nested object field must not satisfy a top-level key of the same name.
# `cover.alt` being declared says nothing about a top-level `alt`.
cleanup
make_config_nested cover image alt
make_post p1.md cover alt
run "nested field name does not satisfy top-level key exits 1" 1

# The object field itself is top-level and still counts.
cleanup
make_config_nested cover image alt
make_post p1.md cover
run "object field itself is declared exits 0" 0

# Every collection is scanned, not only the first.
cleanup
begin_config
add_collection posts content/posts title date
add_collection talks content/talks title date
make_post p1.md title date
make_entry content/talks t1.md title date cover
run "undeclared key in a later collection exits 1" 1

# The check is per-collection: a field declared on posts does not license the
# same key on talks. This is the case Sveltia actually enforces on save.
cleanup
begin_config
add_collection posts content/posts title series
add_collection talks content/talks title
make_post p1.md title series
make_entry content/talks t1.md title series
run "key declared on another collection does not satisfy exits 1" 1

# Same fixture, minus the borrowed key → exits 0.
cleanup
begin_config
add_collection posts content/posts title series
add_collection talks content/talks title
make_post p1.md title series
make_entry content/talks t1.md title
run "each collection satisfied by its own fields exits 0" 0

# Hugo section pages are not CMS entries; their keys must not fail the guard.
cleanup
make_config title
make_post p1.md title
make_entry content/posts _index.md title comments
run "_index.md keys are ignored exits 0" 0

# No collection folder resolves to a real directory → exits 1 rather than
# reporting success on an empty scan.
cleanup
begin_config
add_collection posts content/posts title
run "no collection folder present exits 1" 1

echo
echo "$((PASS + FAIL)) tests run — $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
