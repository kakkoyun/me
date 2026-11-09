# Hugo blog Makefile
# Common commands for blog management and Netlify deployment

# Variables
HUGO_SITE_DIR := .
PUBLIC_DIR := public

# Hugo version comes from mise.toml, the single source of truth for tool
# versions (https://mise.jdx.dev). A plain sed, not mise, so this variable
# expands even on a machine without mise — the netlify build targets use it.
HUGO_VERSION := $(shell sed -n 's/^hugo-extended *= *"\([^"]*\)".*/\1/p' mise.toml)

# Every tool the targets below run is pinned in mise.toml and run through
# `mise exec --`, so recipes resolve the pinned build whether or not the
# shell has mise activated. `make tools` (mise install) fetches everything
# up front; see the require-mise target for the one-time mise install.
MISE := mise exec --
# Hugo is wrapped like every other tool: a bare `hugo` would resolve to
# whatever happens to be on PATH (a brew build, possibly the non-extended
# binary) while check-hugo asserts the mise pin — the exact drift the
# check exists to stop.
HUGO := $(MISE) hugo

.PHONY: fmt fmt-check
.PHONY: tools bootstrap submodules vale-packages require-runtime require-netlify
.PHONY: links links-external lighthouse
.PHONY: print-shell-files require-mise
.PHONY: build serve serve-draft clean minify production netlify-deploy netlify-preview netlify-open list version netlify-update netlify-dev netlify-status netlify-logs netlify-init netlify-env netlify-build netlify-build-preview netlify-build-branch netlify-redirects netlify-validate-config deploy-all check-hugo local-setup verify buffer-update humanizer-update shellcheck actionlint lint test check vale vale-sync prose email-validate

# Default target
help:
	@echo "Hugo Blog Makefile Commands:"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make bootstrap          - mise install + submodules + Vale packages"
	@echo "  make tools              - Install pinned tools (see mise.toml)"
	@echo "  make local-setup        - Bootstrap, then verify Hugo can build"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build              - Build the site"
	@echo "  make serve              - Run local development server"
	@echo "  make serve-draft        - Run local server with drafts enabled"
	@echo "  make clean              - Remove generated files"
	@echo "  make minify             - Build with minification enabled"
	@echo "  make production         - Build for production with all optimizations"
	@echo ""
	@echo "Netlify Commands:"
	@echo "  make netlify-deploy     - Deploy to Netlify production"
	@echo "  make netlify-preview    - Create Netlify deploy preview"
	@echo "  make netlify-open       - Open Netlify site dashboard"
	@echo "  make netlify-dev        - Start Netlify dev environment"
	@echo "  make netlify-status     - Show Netlify site status"
	@echo "  make netlify-logs       - Show Netlify deployment logs"
	@echo "  make netlify-build      - Run Netlify production build locally"
	@echo "  make netlify-build-preview - Run Netlify preview build locally"
	@echo "  make netlify-build-branch - Run Netlify branch deploy build locally"
	@echo "  make netlify-init       - Initialize Netlify CLI"
	@echo "  make netlify-env        - Show Netlify environment variables"
	@echo "  make netlify-redirects  - Show Netlify redirect rules"
	@echo "  make netlify-validate-config - Validate netlify.toml configuration"
	@echo "  make netlify-update     - Update Netlify CLI"
	@echo ""
	@echo "Update Commands:"
	@echo "  make theme-update       - Update PaperMod theme"
	@echo "  make buffer-update      - Update buffer-cli submodule"
	@echo "  make humanizer-update   - Update humanizer skill submodule"
	@echo "  make update-version     - Update Hugo to latest and sync version files"
	@echo "  make update             - Run all update commands"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make verify             - Run post-build SEO/analytics smoke tests"
	@echo "  make deploy-all         - Validate config, build, verify, and deploy to production"
	@echo "  make list               - List all content in the site"
	@echo "  make version            - Check Hugo version"
	@echo ""
	@echo "Quality Commands:"
	@echo "  make test               - Run unit tests for scripts"
	@echo "  make shellcheck         - Run shellcheck on all shell scripts"
	@echo "  make actionlint         - Run actionlint on GitHub Actions workflows"
	@echo "  make lint               - Run shellcheck + actionlint"
	@echo "  make check              - Run lint + test (pre-commit gate)"
	@echo "  make vale-sync          - Fetch third-party Vale style packages"
	@echo "  make vale               - Run Vale prose linter on content/"
	@echo "  make prose              - Run Vale and print a finding-count summary"
	@echo "  make links              - Offline internal link check (mirrors CI)"
	@echo "  make links-external     - Full external link check (mirrors weekly cron)"
	@echo "  make lighthouse         - Lighthouse CI against the local build"
	@echo ""
	@echo "Tool versions are pinned in mise.toml; install mise, then 'make tools'."

# Build the site
build: check-hugo
	$(HUGO) --source $(HUGO_SITE_DIR)

# Run development server (without drafts)
serve: check-hugo
	$(HUGO) server --source $(HUGO_SITE_DIR) --disableFastRender

# Run development server with drafts
serve-draft: check-hugo
	$(HUGO) server --source $(HUGO_SITE_DIR) --buildDrafts --buildFuture --disableFastRender

# Clean generated files
clean: check-hugo
	rm -rf $(PUBLIC_DIR)
	$(HUGO) --cleanDestinationDir --source $(HUGO_SITE_DIR)

# Build with minification
minify: check-hugo
	$(HUGO) --minify --source $(HUGO_SITE_DIR)

# Production build with all optimizations (matches netlify.toml production command)
production: check-hugo
	$(HUGO) --gc --minify --enableGitInfo --source $(HUGO_SITE_DIR)

# Deploy to Netlify production
netlify-deploy: check-hugo require-netlify
	$(HUGO) --gc --minify --enableGitInfo --source $(HUGO_SITE_DIR)
	netlify deploy --prod

# Create Netlify deploy preview
netlify-preview: check-hugo require-netlify
	$(HUGO) --gc --minify --buildFuture --source $(HUGO_SITE_DIR)
	netlify deploy

# Open Netlify site dashboard
netlify-open: require-netlify
	netlify open

# Start Netlify dev environment
netlify-dev: require-netlify
	netlify dev

# Show Netlify site status
netlify-status: require-netlify
	netlify status

# Show Netlify deployment logs
netlify-logs: require-netlify
	netlify sites:list
	@echo "Run 'netlify open:logs' to open logs in browser"

# Update Netlify CLI
netlify-update:
	npm update -g netlify-cli

# Initialize Netlify CLI with site
netlify-init: require-netlify
	netlify init

# Show Netlify environment variables
netlify-env: require-netlify
	netlify env:list

# Show Netlify redirect rules
netlify-redirects:
	@echo "Checking redirect rules from netlify.toml..."
	@grep -A 4 "redirects" netlify.toml
	@echo "\nVerify Obsidian notes redirect at: https://kakkoyun.me/notes/"

# Validate netlify.toml configuration. Version consistency (mise.toml ==
# netlify.toml, all three contexts) is asserted by check-hugo; this target
# additionally exercises netlify-cli against the config.
netlify-validate-config: check-hugo require-netlify
	@echo "Validating netlify.toml configuration..."
	@echo "✅ Hugo version consistent: mise.toml == netlify.toml (asserted by check-hugo)"
	@cat netlify.toml
	@echo "\nLocal Hugo version:"
	@$(MISE) hugo version
	@netlify sites:list
	@echo "\nConfig validation complete."

# Post-build SEO/analytics smoke test
verify:
	@bash scripts/verify-build.sh $(PUBLIC_DIR)

# All-in-one deployment command
deploy-all: netlify-validate-config clean production verify
	@echo "\n=== Starting deployment to Netlify ==="
	netlify deploy --prod --message "Deploy via Makefile deploy-all"
	@echo "\n=== Deployment complete ==="
	@echo "View your site at: https://kakkoyun.me"
	@echo "View Netlify dashboard: https://app.netlify.com/sites/kakkoyun/deploys"

# Run Netlify production build locally (using build command from netlify.toml)
netlify-build: require-netlify
	HUGO_VERSION=$(HUGO_VERSION) HUGO_ENV=production HUGO_ENABLEGITINFO=true netlify build

# Run Netlify deploy preview build locally
netlify-build-preview: require-netlify
	HUGO_VERSION=$(HUGO_VERSION) netlify build --context deploy-preview

# Run Netlify branch deploy build locally
netlify-build-branch: require-netlify
	HUGO_VERSION=$(HUGO_VERSION) netlify build --context branch-deploy

# List all content in the site
list: check-hugo
	$(HUGO) list all

# Check Hugo version
version: check-hugo
	$(HUGO) version

# Update commands
update: update-version theme-update buffer-update humanizer-update

theme-update:
	git submodule update --remote --merge

buffer-update:
	git submodule update --init --remote --merge -- tools/buffer-cli

humanizer-update:
	git submodule update --init --remote --merge -- tools/humanizer

# Update Hugo to the latest release and sync the version everywhere.
#
# `--pin` is load-bearing: without it, mise writes the requested `latest`
# into mise.toml instead of the resolved version, and a literal `latest`
# stops both Renovate's Hugo manager and check-hugo from reading the pin.
update-version: require-mise
	@echo "🔄 Updating Hugo to the latest version..."
	mise use --pin hugo-extended@latest
	@:; \
	pin="$$(sed -n 's/^hugo-extended *= *"\([^"]*\)".*/\1/p' mise.toml)"; \
	[ -n "$$pin" ] || { echo "❌ no hugo-extended pin found in mise.toml"; exit 1; }; \
	sed -i.bak "s/HUGO_VERSION = \"[^\"]*\"/HUGO_VERSION = \"$$pin\"/g" netlify.toml; \
	rm -f netlify.toml.bak; \
	echo "✅ Hugo updated to $$pin in:"; \
	echo "  - mise.toml"; \
	echo "  - netlify.toml (all contexts)"

# Ensure Hugo is present, pinned, the EXTENDED build, and mirrored into
# netlify.toml.
#
# Extended is non-negotiable: standard Hugo has no WebP or libsass, so image
# processing differs from CI and Netlify and scripts/check-image-sizes.sh can
# pass on one and fail on the other. mise installs hugo-extended at the
# mise.toml pin. netlify.toml must mirror that pin in all three contexts
# (production, deploy-preview, branch-deploy) because Netlify builds with its
# own Hugo — Renovate updates both files in one PR; this check catches drift.
check-hugo: require-mise submodules
	@$(MISE) hugo version | awk '{print "✅ Hugo OK: " $$1, $$2}'; \
	$(MISE) hugo version | grep -q extended || { echo "❌ Hugo is not the extended build"; exit 1; }; \
	pin="$$(sed -n 's/^hugo-extended *= *"\([^"]*\)".*/\1/p' mise.toml)"; \
	[ "$$pin" = "$$(mise exec -- hugo version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v)" ] || { echo "❌ Hugo version mismatch: mise.toml=$$pin but installed=$$(mise exec -- hugo version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v)"; echo "   Run: mise install"; exit 1; }; \
	total="$$(grep -c 'HUGO_VERSION' netlify.toml || true)"; \
	matched="$$(grep -cF 'HUGO_VERSION = "'"$$pin"'"' netlify.toml || true)"; \
	[ "$$total" != "0" ] && [ "$$total" = "$$matched" ] || { echo "❌ netlify.toml must mirror the pin $$pin in every HUGO_VERSION context ($$matched/$$total lines match)"; echo "   Run: make update-version"; exit 1; }; \
	echo "✅ Version consistent: mise.toml == installed == netlify.toml ($$pin)"

# Every shell script we own. Discovered by shebang across the whole repo, not
# by extension and not rooted at scripts/, so two things stay covered for free:
# extensionless executables like scripts/buffer (which `*.sh` silently skipped
# in both the Makefile and CI), and any script added outside scripts/ later.
# Submodules and build output are excluded — we do not format vendored code.
SHELL_FILES = $(shell grep -rIl --exclude-dir=.git --exclude-dir=themes \
	--exclude-dir=tools --exclude-dir=.tools --exclude-dir=public --exclude-dir=node_modules \
	-E '^#!.*(bash|sh)$$' . 2>/dev/null | sed 's|^\./||' | sort)

# ── Tooling ───────────────────────────────────────────────────────────────────────────
# mise is the one prerequisite a fresh checkout does not install itself; every
# tool and version lives in mise.toml and `make tools` (mise install) fetches
# them all. Recipes run tools through `mise exec --`, so the pinned build wins
# over any brew- or apt-installed copy on PATH.
require-mise:
	@command -v mise >/dev/null 2>&1 || { \
		echo "❌ mise not found. Install it once per machine:"; \
		echo "   brew install mise   (or: curl https://mise.run | sh)"; \
		echo "   Then run: make tools"; exit 1; }

# Install every pinned tool without running anything.
tools: require-mise
	mise install

# The theme is a submodule: a fresh clone has an empty themes/PaperMod and every
# hugo target dies with a bare "found no layout file".
#
# Checks every gitlink, not just the theme. `git submodule status` prefixes an
# uninitialized entry with '-', so this also catches tools/buffer-cli and
# tools/humanizer — which a themes/PaperMod-only test would leave empty while
# reporting the checkout ready.
submodules:
	@git submodule status --recursive 2>/dev/null | grep -q '^-' || exit 0; \
	echo "➡️  Initializing git submodules..."; \
	git submodule update --init --recursive

# Vale's third-party style packages are gitignored and fetched by `vale sync`,
# so `make vale` on a fresh checkout fails on missing rules without this.
vale-packages: require-mise
	@if [ ! -d styles/proselint ] || [ ! -d styles/write-good ]; then \
	  echo "➡️  Syncing Vale style packages..."; \
	  $(MISE) vale sync; \
	fi

# Everything a fresh checkout needs before any other target.
bootstrap: tools submodules vale-packages
	@echo "✅ Ready. Run 'make check' (lint + test) or 'make serve'."

# Interpreters the script tests shell out to. These come from the OS, so this
# guard only fails with an accurate hint — it cannot install them.
require-runtime:
	@missing=""; \
	for c in python3 curl git; do \
	  command -v $$c >/dev/null 2>&1 || missing="$$missing $$c"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "❌ Missing required tool(s):$$missing"; \
	  echo "   Install them with your OS package manager (apt-get install …, brew install …)."; \
	  exit 1; \
	fi

# Deliberately NOT auto-installed: netlify-cli is a global npm package that also
# needs an interactive login, so installing it unasked is the wrong call.
require-netlify:
	@command -v netlify >/dev/null 2>&1 || { \
	  echo "❌ netlify CLI not found. Install with: npm install -g netlify-cli"; \
	  echo "   Then authenticate with: netlify login"; \
	  exit 1; }

# Consumed by CI so the workflows never re-implement Makefile logic.
print-shell-files:
	@printf '%s\n' $(SHELL_FILES)

# Run shellcheck on all shell scripts.
# Source-following comes from .shellcheckrc (external-sources=true), which is
# what makes the `# shellcheck source=` directives in scripts/ do anything.
shellcheck: require-mise
	$(MISE) shellcheck $(SHELL_FILES)

# Run actionlint on all GitHub Actions workflows
actionlint: require-mise
	$(MISE) actionlint .github/workflows/*.yml

# Format shell scripts in place. Style comes from .editorconfig, which shfmt
# reads directly — there are deliberately no formatting flags here to drift.
fmt: require-mise
	$(MISE) shfmt -w $(SHELL_FILES)

# Fail if anything is unformatted. This is the gate; `make fmt` is the fix.
#
# A formatter is only reproducible if everyone runs the same build: a different
# version can reformat files that are already conformant, producing churn
# nobody asked for. The pinned shfmt from mise.toml runs through `mise exec --`,
# so this is guaranteed rather than warned about.
fmt-check: require-mise
	@out=$$($(MISE) shfmt -l $(SHELL_FILES)); \
	if [ -n "$$out" ]; then \
	  echo "❌ Not shfmt-formatted:"; echo "$$out" | sed 's/^/   /'; \
	  echo "   Run: make fmt"; exit 1; \
	else echo "✅ shfmt: all shell scripts formatted"; fi

# Run all linters
lint: fmt-check shellcheck actionlint

# Run unit tests for scripts
test: require-runtime
	@bash scripts/test-find-promotable-posts.sh
	@bash scripts/test-check-post-live.sh
	@bash scripts/test-posts-publishing-today.sh
	@bash scripts/test-check-cms-fields.sh
	@bash scripts/test-record-promotion.sh
	@bash scripts/test-check-frontmatter.sh
	@bash scripts/test-check-admin-csp.sh
	@bash scripts/test-check-live-headers.sh
	@bash scripts/test-check-repo-access.sh
	@bash scripts/test-check-image-sizes.sh
	@bash scripts/test-lighthouse-summary.sh
	@bash scripts/check-cms-fields.sh
	@bash scripts/check-frontmatter.sh
	@bash scripts/check-admin-csp.sh

# Pre-commit gate: every static + dynamic check we run in CI.
# Run this locally before pushing to catch issues before the PR opens.
check: lint test

# Fetch third-party Vale style packages declared in .vale.ini
vale-sync: require-mise
	$(MISE) vale sync

# Run Vale prose linter on content/
vale: vale-packages
	$(MISE) vale content/

# Run Vale advisory (does not fail the build); shows findings + summary
prose: vale-packages
	@echo "📝 Running Vale on content/ ..."
	@$(MISE) vale --no-exit content/

# Local equivalent of the links-internal job in .github/workflows/links.yml.
# Everything both sides share lives in lychee.toml so the two cannot drift;
# only the path-dependent flags are spelled out here. See that file for why
# each setting is what it is.
links: require-mise production
	$(MISE) lychee --config lychee.toml \
	  --offline \
	  --root-dir "$(CURDIR)/$(PUBLIC_DIR)" \
	  --index-files index.html,. \
	  --include-fragments \
	  './$(PUBLIC_DIR)/**/*.html'

# Local equivalent of the links-external job (the weekly cron). Hits the
# network; soft-fails in CI but not here, where you asked for it.
links-external: require-mise
	$(MISE) lychee --config lychee.toml \
	  --cache \
	  --cache-exclude-status '429,500..=599' \
	  --base 'https://kakkoyun.me' \
	  './content/**/*.md'

# Local equivalent of the lighthouse job in .github/workflows/build.yml, using
# the same .lighthouserc.yml thresholds. Needs a Chrome or Chromium binary;
# override the search with CHROME_PATH=/path/to/chrome. lhci comes from mise
# (npm:@lhci/cli in mise.toml); CI's job uses the treosh action's bundled copy.
lighthouse: require-mise production
	@chrome="$(CHROME_PATH)"; \
	if [ -z "$$chrome" ]; then \
	  for c in google-chrome google-chrome-stable chromium chromium-browser; do \
	    if command -v $$c >/dev/null 2>&1; then chrome=$$(command -v $$c); break; fi; \
	  done; \
	fi; \
	if [ -z "$$chrome" ]; then \
	  for c in /opt/pw-browsers/chromium \
	           "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do \
	    if [ -x "$$c" ]; then chrome="$$c"; break; fi; \
	  done; \
	fi; \
	if [ -z "$$chrome" ]; then \
	  echo "❌ No Chrome/Chromium found."; \
	  echo "   Install Google Chrome, or point at one: CHROME_PATH=/path/to/chrome make lighthouse"; \
	  exit 1; \
	fi; \
	echo "➡️  Using Chrome: $$chrome"; \
	flags=""; \
	if [ "$$(id -u)" = "0" ]; then \
	  echo "   (running as root: adding --no-sandbox, which Chrome requires there)"; \
	  flags="--collect.settings.chromeFlags=--no-sandbox"; \
	fi; \
	CHROME_PATH="$$chrome" $(MISE) lhci \
	  autorun --config=.lighthouserc.yml $$flags

# Validate every MJML email template under templates/emails/. Catches
# both MJML syntax errors and a Hakanai-specific pitfall (Mustache
# tokens inside HTML comments). mjml comes from mise (npm:mjml in
# mise.toml); the script calls a bare `mjml` from PATH, so the Makefile
# wraps it in `mise exec --` and the script stays independent of any
# particular wrapper.
email-validate: require-mise
	@$(MISE) bash scripts/validate-emails.sh

local-setup: check-hugo ## Initialize local dev environment (Hugo + theme submodule + dry run)
	@echo "🔧 Local development environment setup"
	@echo "➡️  Verifying Hugo can build (dry run)..."
	@$(HUGO) --quiet --renderToMemory || { echo "❌ Hugo build failed"; exit 1; }
	@echo "✅ Basic build succeeded"
	@echo "Next steps:"; \
	 echo "  make serve        # start dev server"; \
	 echo "  make serve-draft  # include drafts & future posts";
