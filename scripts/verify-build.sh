#!/usr/bin/env bash
# Post-build SEO/analytics smoke test.
# Usage: bash scripts/verify-build.sh [public_dir]
# Exits 0 on success, 1 if any check fails.
set -euo pipefail

PUBLIC_DIR="${1:-public}"
ERRORS=0

fail() {
  echo "FAIL: $1"
  ERRORS=$((ERRORS + 1))
}

# 1. robots.txt must exist and allow crawling
if [ ! -f "$PUBLIC_DIR/robots.txt" ]; then
  fail "robots.txt not found in $PUBLIC_DIR"
elif ! grep -q 'Allow: /' "$PUBLIC_DIR/robots.txt"; then
  fail "robots.txt missing 'Allow: /'"
fi

# 2. robots.txt must not point to localhost
if grep -qi 'localhost' "$PUBLIC_DIR/robots.txt"; then
  fail "robots.txt contains localhost URLs"
fi

# 3. sitemap.xml must not contain localhost
if grep -qi 'localhost' "$PUBLIC_DIR/sitemap.xml"; then
  fail "sitemap.xml contains localhost URLs"
fi

# 4. sitemap.xml must not include /search/
if grep -q '/search/' "$PUBLIC_DIR/sitemap.xml"; then
  fail "sitemap.xml contains /search/ (should be excluded)"
fi

# Find a sample post page for HTML checks
SAMPLE_PAGE=$(find "$PUBLIC_DIR" -name 'index.html' -path '*/posts/*' | head -1)

if [ -n "$SAMPLE_PAGE" ]; then
  # 5. Production pages must not have noindex
  if grep -q 'content="noindex' "$SAMPLE_PAGE"; then
    fail "Production pages have noindex meta tag ($SAMPLE_PAGE)"
  fi

  # 6. Plausible script URL must not contain a space after https://
  if grep -q 'https:// ' "$SAMPLE_PAGE"; then
    fail "Broken URL detected (space after 'https://') in $SAMPLE_PAGE"
  fi

  # 7. No empty href in alternate link tags
  if grep -qE 'href=""[^>]*rel="alternate"' "$SAMPLE_PAGE" || grep -qE 'rel="alternate"[^>]*href=""' "$SAMPLE_PAGE"; then
    fail "Empty href in alternate link tag in $SAMPLE_PAGE"
  fi
else
  echo "WARN: No post index.html found under $PUBLIC_DIR/posts/ — skipping HTML checks"
fi

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "FAILED: $ERRORS check(s) failed"
  exit 1
fi

echo "OK: All SEO/analytics smoke checks passed"
