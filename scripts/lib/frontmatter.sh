#!/usr/bin/env bash
# Shared YAML frontmatter helpers for the content scripts.
#
# Sourced, never executed:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/frontmatter.sh"
#
# Every script that reads a post's frontmatter used to carry its own copy of the
# awk extractor below — find-promotable-posts.sh and posts-publishing-today.sh
# had byte-identical versions, the latter carrying a comment promising to keep
# them in sync by hand. This file is that promise, kept by the shell instead.
#
# Scope is deliberately narrow: top-level keys in the leading `---` block. It is
# not a YAML parser and must not grow into one. Hugo already validates the real
# YAML on every build (build.yml runs a full production build on every PR), so
# these helpers only need to be right about the shapes this repo actually writes.

# Emit only the YAML frontmatter block (lines between the first two `---`).
# Empty output when the file has no frontmatter — callers handle that as
# "no match" rather than an error, since a bodyless or malformed file is not
# this function's problem to report.
fm_block() {
  awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if (n==2) exit; next} n==1' "$1"
}

# fm_has <file> <key> — true when the frontmatter declares <key> at top level.
# Anchored to column 0 so a nested key (`  alt:` under `cover:`) or a body line
# that happens to look like YAML does not count.
fm_has() {
  fm_block "$1" | grep -q "^$2:"
}

# fm_get <file> <key> — first value of a top-level scalar key, unquoted.
# Empty output (exit 0) when the key is absent; callers must handle that.
fm_get() {
  local line
  line=$(fm_block "$1" | grep -m1 "^$2:" || true)
  [ -z "$line" ] && return 0
  printf '%s\n' "$line" | sed "s/^$2:[[:space:]]*//" | tr -d '"' | sed "s/^'//; s/'$//"
}

# fm_list <file> <key> — items of a top-level block list, one per line:
#
#   promotedAt:
#     - 2026-08-21T06:03:00Z
#     - 2026-09-04T06:02:00Z
#
# Stops at the next top-level key, so it never bleeds into a following list.
# Inline flow lists (`key: [a, b]`) are not supported — nothing in this repo
# writes them, and check-frontmatter.sh rejects them rather than let one parse
# as empty and silently look like "never promoted".
fm_list() {
  fm_block "$1" | awk -v key="$2" '
    $0 ~ "^" key ":[[:space:]]*$" { inlist = 1; next }
    inlist && /^[[:space:]]+-[[:space:]]*/ {
      sub(/^[[:space:]]+-[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      if (length($0)) print
      next
    }
    inlist && /^[^[:space:]]/ { inlist = 0 }
  '
}

# fm_append_list <file> <key> <value> — append <value> to a top-level block
# list, creating the key at the end of the frontmatter when absent. Writes the
# rewritten file to stdout; the caller owns the temp-file/validate/mv dance.
#
# Indentation matches the repo's existing block lists (`categories`, `tags`):
# two spaces before the dash. Values are written unquoted, per CLAUDE.md.
fm_append_list() {
  awk -v key="$2" -v val="$3" '
    BEGIN { n = 0; done = 0; inlist = 0 }
    /^---[[:space:]]*$/ {
      n++
      if (n == 2 && !done) {
        # The list ran right up to the closing delimiter: append inside it.
        # Otherwise the key is absent entirely, so create it here.
        if (inlist) { print "  - " val }
        else        { print key ":"; print "  - " val }
        done = 1
        inlist = 0
      }
      print
      next
    }
    n == 1 && $0 ~ "^" key ":[[:space:]]*$" { inlist = 1; print; next }
    # First line that ends the list block is where the new item belongs, so the
    # appended entry stays inside the list rather than after the next key.
    inlist && n == 1 && !/^[[:space:]]+-[[:space:]]*/ {
      print "  - " val
      inlist = 0
      done = 1
      print
      next
    }
    { print }
    END {
      # Malformed input: frontmatter never closed. Emit the value so the caller
      # sees a change, and let the validation in record-promotion.sh reject it.
      if (!done) print "  - " val
    }
  ' "$1"
}
