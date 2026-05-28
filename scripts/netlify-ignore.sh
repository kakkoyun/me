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

# Anything outside this list (.github/, .claude/, the rest of scripts/,
# docs/, Makefile, *.md at the repo root, .vale.ini, styles/,
# renovate.json, tools/, .gitignore, .gitmodules, .lighthouserc.yml)
# does not change what Hugo renders and does not need a preview.
# `scripts/netlify-ignore.sh` is itself included so a change to the
# deploy gate triggers a verifying build.
BUILD_PATHS=(
  ".hugo-version"
  "archetypes/"
  "assets/"
  "config.yaml"
  "content/"
  "layouts/"
  "netlify.toml"
  "scripts/netlify-ignore.sh"
  "static/"
  "themes/"
)

# Netlify exposes the build hook JSON body as INCOMING_HOOK_BODY. The
# promote-post cron sets {"force":true} so future-dated posts can go live
# on their publishDate even though no commit landed.
if [[ "${INCOMING_HOOK_BODY:-}" == *'"force":true'* ]]; then
  echo "netlify-ignore: incoming hook requested force build, building."
  exit 1
fi

# Bot-authored PRs (Renovate, Dependabot) don't need a Netlify preview —
# build.yml already runs Hugo + verify + Lighthouse on every PR. Override
# per-PR by pushing an empty commit with `[netlify]` in the subject:
#   git commit --allow-empty -m "[netlify] preview please"
# Scoped to non-production contexts so Renovate-merged commits landing on
# master still deploy.
if [[ "${CONTEXT:-}" != "production" ]]; then
  head_subject=$(git log -1 --format='%s' HEAD 2>/dev/null || echo "")
  head_author=$(git log -1 --format='%ae' HEAD 2>/dev/null || echo "")
  if [[ "${head_subject}" != *'[netlify]'* ]]; then
    case "${HEAD:-}" in
      renovate/*|dependabot/*)
        echo "netlify-ignore: bot branch ${HEAD}, skipping preview (build.yml validates this). Override with [netlify] in commit subject."
        exit 0
        ;;
    esac
    if [[ "${head_author}" == *renovate* ]] || [[ "${head_author}" == *dependabot* ]]; then
      echo "netlify-ignore: bot author ${head_author}, skipping preview (build.yml validates this). Override with [netlify] in commit subject."
      exit 0
    fi
  fi
fi

# First deploy on this branch — nothing to diff against. Build.
if [[ -z "${CACHED_COMMIT_REF:-}" ]]; then
  echo "netlify-ignore: no cached commit, building."
  exit 1
fi

# Netlify always sets COMMIT_REF; guard explicitly so local runs or
# unexpected env shape fall through to "build" instead of erroring on `set -u`.
if [[ -z "${COMMIT_REF:-}" ]]; then
  echo "netlify-ignore: COMMIT_REF not set, building."
  exit 1
fi

# Manual redeploy of the same commit — nothing changed, by definition.
if [[ "${CACHED_COMMIT_REF}" == "${COMMIT_REF}" ]]; then
  echo "netlify-ignore: cached commit == current commit, skipping."
  exit 0
fi

if git diff --quiet "${CACHED_COMMIT_REF}" "${COMMIT_REF}" -- "${BUILD_PATHS[@]}"; then
  echo "netlify-ignore: no site-affecting paths changed since ${CACHED_COMMIT_REF}, skipping."
  exit 0
fi

echo "netlify-ignore: site-affecting paths changed since ${CACHED_COMMIT_REF}, building."
exit 1
