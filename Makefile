# Hugo blog Makefile
# Common commands for blog management and Netlify deployment

# Variables
HUGO_SITE_DIR := .
PUBLIC_DIR := public
HUGO_VERSION := $(shell cat .hugo-version)

# Pinned versions of every tool the checks below run. CI reads this same file,
# so a check that passes here runs the same binary CI runs. See tools.mk.
include tools.mk

# Where scripts/ensure-tool.sh installs the pinned tools. FIRST on PATH, so the
# pin wins over a brew- or apt-installed copy of the same tool.
TOOLS_BIN := $(CURDIR)/.tools/bin

# Ensure go-installed binaries are visible in every recipe shell.
# Prefer GOBIN when set; fall back to GOPATH/bin.
GO_INSTALL_BIN := $(shell go env GOBIN 2>/dev/null)
ifeq ($(GO_INSTALL_BIN),)
  GO_INSTALL_BIN := $(shell go env GOPATH 2>/dev/null)/bin
endif
export PATH := $(TOOLS_BIN):$(PATH):$(GO_INSTALL_BIN)

.PHONY: fmt fmt-check
.PHONY: tools bootstrap submodules vale-packages require-runtime require-netlify
.PHONY: links links-external lighthouse
.PHONY: print-shell-files print-tool-version print-tools-bin
.PHONY: build serve serve-draft clean minify production netlify-deploy netlify-preview netlify-open list version netlify-update netlify-dev netlify-status netlify-logs netlify-init netlify-env netlify-build netlify-build-preview netlify-build-branch netlify-redirects netlify-validate-config deploy-all check-hugo local-setup verify buffer-update humanizer-update shellcheck actionlint lint test check vale vale-sync prose email-validate

# Default target
help:
	@echo "Hugo Blog Makefile Commands:"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make bootstrap          - Install pinned tools + submodules + Vale packages"
	@echo "  make tools              - Install pinned tools only (see tools.mk)"
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
	@echo "  make hugo-update        - Update Hugo to latest version"
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
	@echo "Tool versions are pinned in tools.mk and installed on first use."

# Build the site
build: check-hugo
	hugo --source $(HUGO_SITE_DIR)

# Run development server (without drafts)
serve: check-hugo
	hugo server --source $(HUGO_SITE_DIR) --disableFastRender

# Run development server with drafts
serve-draft: check-hugo
	hugo server --source $(HUGO_SITE_DIR) --buildDrafts --buildFuture --disableFastRender

# Clean generated files
clean: check-hugo
	rm -rf $(PUBLIC_DIR)
	hugo --cleanDestinationDir --source $(HUGO_SITE_DIR)

# Build with minification
minify: check-hugo
	hugo --minify --source $(HUGO_SITE_DIR)

# Production build with all optimizations (matches netlify.toml production command)
production: check-hugo
	hugo --gc --minify --enableGitInfo --source $(HUGO_SITE_DIR)

# Deploy to Netlify production
netlify-deploy: check-hugo require-netlify
	hugo --gc --minify --enableGitInfo --source $(HUGO_SITE_DIR)
	netlify deploy --prod

# Create Netlify deploy preview
netlify-preview: check-hugo require-netlify
	hugo --gc --minify --buildFuture --source $(HUGO_SITE_DIR)
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

# Validate netlify.toml configuration
netlify-validate-config: check-hugo require-netlify
	@echo "Validating netlify.toml configuration..."
	@PINNED=$$(cat .hugo-version 2>/dev/null | tr -d '[:space:]'); \
	TOML=$$(grep 'HUGO_VERSION' netlify.toml | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); \
	if [ "$$PINNED" != "$$TOML" ]; then \
	  echo "❌ Version mismatch: .hugo-version=$$PINNED but netlify.toml=$$TOML"; \
	  echo "   Run: make update-version"; \
	  exit 1; \
	fi; \
	echo "✅ Hugo version consistent: $$PINNED (.hugo-version matches netlify.toml)"
	@cat netlify.toml
	@echo "\nLocal Hugo version:"
	@hugo version
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
	hugo list all

# Check Hugo version
version: check-hugo
	hugo version

# Update commands
update: update-version theme-update buffer-update humanizer-update

hugo-update:
	go install github.com/gohugoio/hugo@latest

theme-update:
	git submodule update --remote --merge

buffer-update:
	git submodule update --init --remote --merge -- tools/buffer-cli

humanizer-update:
	git submodule update --init --remote --merge -- tools/humanizer

# Update Hugo to latest version and sync version across all files
update-version:
	@echo "🔄 Updating Hugo to the latest version..."
	@$(MAKE) hugo-update
	@echo "📖 Reading installed Hugo version..."
	@INSTALLED_VERSION=$$(hugo version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/v//' || echo "unknown"); \
	if [ "$$INSTALLED_VERSION" = "unknown" ]; then \
		echo "❌ Could not detect Hugo version. Please ensure Hugo is installed and in PATH."; \
		exit 1; \
	fi; \
	echo "✅ Detected Hugo version: $$INSTALLED_VERSION"; \
	echo "🔄 Updating version files from $$(cat .hugo-version 2>/dev/null || echo 'unknown') to $$INSTALLED_VERSION"; \
	echo "$$INSTALLED_VERSION" > .hugo-version; \
	sed -i "s/HUGO_VERSION = \"[^\"]*\"/HUGO_VERSION = \"$$INSTALLED_VERSION\"/g" netlify.toml; \
	echo "✅ Updated Hugo version to $$INSTALLED_VERSION in:"; \
	echo "  - .hugo-version"; \
	echo "  - netlify.toml (all contexts)"

# Ensure Hugo is present, pinned, and the EXTENDED build.
#
# This used to `go install github.com/gohugoio/hugo@vX`, which builds the
# STANDARD binary — no WebP, no libsass. CI (peaceiris/actions-hugo with
# extended: true) and Netlify both build extended, so image processing behaved
# differently locally than in CI and scripts/check-image-sizes.sh could pass on
# one and fail on the other. scripts/ensure-tool.sh installs the extended
# release asset at exactly the .hugo-version pin.
check-hugo: tool-hugo submodules
	@hugo version | awk '{print "✅ Hugo OK: " $$1, $$2}'

# Every shell script we own. Discovered by shebang across the whole repo, not
# by extension and not rooted at scripts/, so two things stay covered for free:
# extensionless executables like scripts/buffer (which `*.sh` silently skipped
# in both the Makefile and CI), and any script added outside scripts/ later.
# Submodules and build output are excluded — we do not format vendored code.
SHELL_FILES = $(shell grep -rIl --exclude-dir=.git --exclude-dir=themes \
	--exclude-dir=tools --exclude-dir=.tools --exclude-dir=public --exclude-dir=node_modules \
	-E '^#!.*(bash|sh)$$' . 2>/dev/null | sed 's|^\./||' | sort)

# ── Tooling ───────────────────────────────────────────────────────────────────
# Every check target depends on the tools it needs, so a fresh checkout — a new
# laptop, a worktree, an agent session on a sandbox VM — runs `make check` with
# no manual install step. Versions come from tools.mk; the installer is
# scripts/ensure-tool.sh. Set TOOLS_OFFLINE=1 to fail with a manual-install hint
# instead of downloading.
TOOLS := hugo shfmt shellcheck actionlint vale lychee
.PHONY: $(addprefix tool-,$(TOOLS))

tool-hugo tool-shfmt tool-shellcheck tool-actionlint tool-vale tool-lychee:
	@bash scripts/ensure-tool.sh $(patsubst tool-%,%,$@)

# Install every pinned tool without running anything.
tools: $(addprefix tool-,$(TOOLS))

# The theme is a submodule: a fresh clone has an empty themes/PaperMod and every
# hugo target dies with a bare "found no layout file".
submodules:
	@if [ ! -f themes/PaperMod/theme.toml ]; then \
	  echo "➡️  Initializing git submodules..."; \
	  git submodule update --init --recursive; \
	fi

# Vale's third-party style packages are gitignored and fetched by `vale sync`,
# so `make vale` on a fresh checkout fails on missing rules without this.
vale-packages: tool-vale
	@if [ ! -d styles/proselint ] || [ ! -d styles/write-good ]; then \
	  echo "➡️  Syncing Vale style packages..."; \
	  vale sync; \
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
#
# print-tools-bin exists because the PATH export above only reaches make's own
# recipe shells. A workflow `run:` block is a different shell, so it needs the
# directory appended to $GITHUB_PATH — otherwise a tool that happens to be
# preinstalled on the runner silently wins over the pin, which is the exact
# drift this file is here to prevent.
print-tools-bin:
	@echo "$(TOOLS_BIN)"

print-shell-files:
	@printf '%s\n' $(SHELL_FILES)

print-tool-version:
	@echo "$($(TOOL)_VERSION)"

# Run shellcheck on all shell scripts.
# Source-following comes from .shellcheckrc (external-sources=true), which is
# what makes the `# shellcheck source=` directives in scripts/ do anything.
shellcheck: tool-shellcheck
	shellcheck $(SHELL_FILES)

# Run actionlint on all GitHub Actions workflows
actionlint: tool-actionlint
	actionlint .github/workflows/*.yml

# Format shell scripts in place. Style comes from .editorconfig, which shfmt
# reads directly — there are deliberately no formatting flags here to drift.
fmt: tool-shfmt
	shfmt -w $(SHELL_FILES)

# Fail if anything is unformatted. This is the gate; `make fmt` is the fix.
#
# A formatter is only reproducible if everyone runs the same build: a different
# version can reformat files that are already conformant, producing churn nobody
# asked for. tool-shfmt installs the pinned build from tools.mk and puts it first
# on PATH, so this is now guaranteed rather than warned about.
fmt-check: tool-shfmt
	@out=$$(shfmt -l $(SHELL_FILES)); \
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
	@bash scripts/test-ensure-tool.sh
	@bash scripts/test-lighthouse-summary.sh
	@bash scripts/check-cms-fields.sh
	@bash scripts/check-frontmatter.sh
	@bash scripts/check-admin-csp.sh

# Pre-commit gate: every static + dynamic check we run in CI.
# Run this locally before pushing to catch issues before the PR opens.
check: lint test

# Fetch third-party Vale style packages declared in .vale.ini
vale-sync: tool-vale
	vale sync

# Run Vale prose linter on content/
vale: vale-packages
	vale content/

# Run Vale advisory (does not fail the build); shows findings + summary
prose: vale-packages
	@echo "📝 Running Vale on content/ ..."
	@vale --no-exit content/

# Local equivalent of the links-internal job in .github/workflows/links.yml.
# Everything both sides share lives in lychee.toml so the two cannot drift;
# only the path-dependent flags are spelled out here. See that file for why
# each setting is what it is.
links: tool-lychee production
	lychee --config lychee.toml \
	  --offline \
	  --root-dir "$(CURDIR)/$(PUBLIC_DIR)" \
	  --index-files index.html,. \
	  --include-fragments \
	  './$(PUBLIC_DIR)/**/*.html'

# Local equivalent of the links-external job (the weekly cron). Hits the
# network; soft-fails in CI but not here, where you asked for it.
links-external: tool-lychee
	lychee --config lychee.toml \
	  --cache \
	  --cache-exclude-status '429,500..=599' \
	  --base 'https://kakkoyun.me' \
	  './content/**/*.md'

# Local equivalent of the lighthouse job in .github/workflows/build.yml, using
# the same .lighthouserc.yml thresholds. Needs a Chrome or Chromium binary;
# override the search with CHROME_PATH=/path/to/chrome.
lighthouse: production
	@command -v npx >/dev/null 2>&1 || { echo "❌ npx not found. Install Node.js"; exit 1; }
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
	CHROME_PATH="$$chrome" npx --yes @lhci/cli@$(LHCI_VERSION) \
	  autorun --config=.lighthouserc.yml $$flags

# Validate every MJML email template under templates/emails/. Catches
# both MJML syntax errors and a Hakanai-specific pitfall (Mustache
# tokens inside HTML comments). Requires npx; fetches the pinned mjml
# (tools.mk) on first run.
email-validate:
	@command -v npx >/dev/null 2>&1 || { echo "❌ npx not found. Install Node.js"; exit 1; }
	@MJML_VERSION=$(MJML_VERSION) bash scripts/validate-emails.sh

local-setup: check-hugo ## Initialize local dev environment (Hugo + theme submodule + dry run)
	@echo "🔧 Local development environment setup"
	@echo "➡️  Verifying Hugo can build (dry run)..."
	@hugo --quiet --renderToMemory || { echo "❌ Hugo build failed"; exit 1; }
	@echo "✅ Basic build succeeded"
	@echo "Next steps:"; \
	 echo "  make serve        # start dev server"; \
	 echo "  make serve-draft  # include drafts & future posts";
