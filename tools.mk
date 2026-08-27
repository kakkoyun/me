# Pinned versions of the developer tools the checks in this Makefile run.
#
# Deliberately plain `KEY=value` lines with `#` comments, because three
# different things read this file and none of them should need a parser:
#
#   Makefile   include tools.mk
#   bash       source tools.mk                (scripts/ensure-tool.sh)
#   CI         grep -E '^[A-Z_]+=' tools.mk >> "$GITHUB_ENV"
#
# That is the whole point: CI and a dev machine install the same build of
# the same tool, so a check that passes locally passes in CI. `make lint`
# and friends fetch these on first use via scripts/ensure-tool.sh; nothing
# here needs to be installed by hand.
#
# Versions are stored WITHOUT a leading `v` (matching .hugo-version).
# ensure-tool.sh adds the prefix where a project's tags or asset names use
# one, since no two of them agree.
#
# Renovate keeps these current — see the `tools.mk` custom manager in
# renovate.json. The `# renovate:` comment above each pin is load-bearing:
# it names the datasource and the upstream repo, so adding a new tool means
# adding its comment line and nothing else.
#
# Hugo is NOT pinned here. It lives in .hugo-version, which netlify.toml,
# `make update-version`, build.yml, links.yml and two existing Renovate
# managers all read. ensure-tool.sh special-cases hugo to read that file.
# Do not add a second Hugo pin — the two would drift and Netlify would win.

# renovate: datasource=github-releases depName=mvdan/sh extractVersion=^v(?<version>.*)$
SHFMT_VERSION=3.13.1

# renovate: datasource=github-releases depName=koalaman/shellcheck extractVersion=^v(?<version>.*)$
SHELLCHECK_VERSION=0.11.0

# renovate: datasource=github-releases depName=rhysd/actionlint extractVersion=^v(?<version>.*)$
ACTIONLINT_VERSION=1.7.12

# renovate: datasource=github-releases depName=errata-ai/vale extractVersion=^v(?<version>.*)$
VALE_VERSION=3.19.0

# lychee tags its releases `lychee-vX.Y.Z`, not `vX.Y.Z`.
# renovate: datasource=github-releases depName=lycheeverse/lychee extractVersion=^lychee-v(?<version>.*)$
LYCHEE_VERSION=0.24.2

# Lighthouse CI, run via npx for `make lighthouse`. CI uses the
# treosh/lighthouse-ci-action, which bundles its own copy.
# renovate: datasource=npm depName=@lhci/cli
LHCI_VERSION=0.15.1

# MJML compiler for `make email-validate`. Held on the v4 line on purpose:
# v5 is a breaking rewrite and the templates have not been ported. Renovate
# will offer the major separately — take it in its own PR, with a full
# `make email-validate` pass and a paste-test in the Hakanai dashboard.
# renovate: datasource=npm depName=mjml
MJML_VERSION=5.4.0
