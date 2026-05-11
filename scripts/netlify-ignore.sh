#!/usr/bin/env bash
# Netlify ignore command for non-production deploys.
#
# Wired into [context.deploy-preview] and [context.branch-deploy] in
# netlify.toml. Skips the build (exit 0) when nothing under a path that
# affects the rendered site has changed since the last deployed commit;
# otherwise builds (exit non-zero).
#
# Netlify sets these in the build environment:
#   CACHED_COMMIT_REF  SHA of the last successful deploy on this context
#   COMMIT_REF         SHA being considered for deploy
#   CONTEXT            deploy-preview | branch-deploy | production | ...

set -uo pipefail

# Anything outside this list (.github/, .claude/, scripts/, docs/,
# Makefile, *.md at the repo root, .vale.ini, styles/, renovate.json,
# tools/, .gitignore, .gitmodules, .lighthouserc.yml) does not change
# what Hugo renders and does not need a preview.
BUILD_PATHS=(
  ".hugo-version"
  "archetypes/"
  "assets/"
  "config.yaml"
  "content/"
  "layouts/"
  "netlify.toml"
  "static/"
  "themes/"
)

# First deploy on this branch — nothing to diff against. Build.
if [[ -z "${CACHED_COMMIT_REF:-}" ]]; then
  echo "netlify-ignore: no cached commit, building."
  exit 1
fi

# Manual redeploy of the same commit — nothing changed, by definition.
if [[ "${CACHED_COMMIT_REF}" == "${COMMIT_REF:-}" ]]; then
  echo "netlify-ignore: cached commit == current commit, skipping."
  exit 0
fi

if git diff --quiet "${CACHED_COMMIT_REF}" "${COMMIT_REF}" -- "${BUILD_PATHS[@]}"; then
  echo "netlify-ignore: no site-affecting paths changed since ${CACHED_COMMIT_REF}, skipping."
  exit 0
fi

echo "netlify-ignore: site-affecting paths changed since ${CACHED_COMMIT_REF}, building."
exit 1
