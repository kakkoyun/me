#!/usr/bin/env bash
#
# Validate every MJML template under templates/emails/.
#
# Hakanai Broadcast renders these templates through its own pipeline
# (Mustache substitution + MJML compile), so a clean local pass is
# necessary but not sufficient --- Hakanai may reject things mjml
# accepts. Run `make email-validate` after every edit, and still
# paste-test in the Hakanai dashboard before going live.
#
# Two checks per file:
#   1. mjml --validate strict ... compiles cleanly.
#   2. No Mustache tokens (`{{...}}`, `{{{...}}}`, `{{#...}}`) appear
#      inside HTML comments. Hakanai's Mustache pre-processor isn't
#      comment-aware: a {{description}} mention in a doc comment gets
#      substituted with the article body at send time, which can break
#      MJML parsing once a `-->` ends up inside the comment.
#
# Usage:
#   scripts/validate-emails.sh                   # all templates
#   scripts/validate-emails.sh path/to/foo.mjml  # one template
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_DIR="$ROOT_DIR/templates/emails"

if (( $# > 0 )); then
  targets=("$@")
else
  mapfile -t targets < <(find "$TEMPLATES_DIR" -maxdepth 1 -type f -name '*.mjml' | sort)
fi

if (( ${#targets[@]} == 0 )); then
  echo "validate-emails: no .mjml files found under $TEMPLATES_DIR" >&2
  exit 0
fi

check_no_mustache_in_comments() {
  local tpl="$1"
  # Use Python to walk every <!-- ... --> block and report Mustache hits
  # with the file line where the comment opened.
  python3 - "$tpl" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()

# Find each comment block with its starting line number.
problems = []
pos = 0
while True:
    start = text.find('<!--', pos)
    if start == -1:
        break
    end = text.find('-->', start + 4)
    if end == -1:
        break
    block = text[start:end+3]
    line_no = text.count('\n', 0, start) + 1
    for m in re.finditer(r'\{\{[#^/&!]?[^}]+\}\}', block):
        problems.append((line_no, m.group()))
    pos = end + 3

if problems:
    print(f"  mustache-in-comments check FAILED: {path}")
    for line, token in problems:
        print(f"    line {line}: {token}")
    sys.exit(1)
PY
}

failed=0
for tpl in "${targets[@]}"; do
  echo "  validating $tpl"

  if ! check_no_mustache_in_comments "$tpl"; then
    failed=1
    continue
  fi

  out=$(npx --yes mjml@latest --validate strict "$tpl" -o /dev/null 2>&1) || rc=$?
  rc=${rc:-0}
  if (( rc != 0 )) || grep -qE 'Line [0-9]+|ValidationError|^Error' <<<"$out"; then
    echo "  FAILED: $tpl"
    if [[ -n "$out" ]]; then
      # SC2001-friendly: prepend each line with four spaces using bash
      # parameter expansion (no `sed`). The trailing trailing-newline
      # from $out becomes a 4-space-only trailing line, which printf
      # trims via the format string.
      printf '    %s\n' "${out//$'\n'/$'\n    '}"
    fi
    failed=1
  fi
done

if (( failed )); then
  echo ""
  echo "validate-emails: one or more templates failed validation." >&2
  exit 1
fi

echo "validate-emails: all templates valid."
