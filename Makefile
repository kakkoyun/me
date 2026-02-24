# Hugo blog Makefile
# Common commands for blog management and Netlify deployment

# Variables
HUGO_SITE_DIR := .
PUBLIC_DIR := public
HUGO_VERSION := $(shell cat .hugo-version)

.PHONY: build serve serve-draft clean minify production netlify-deploy netlify-preview netlify-open list version netlify-update netlify-dev netlify-status netlify-logs netlify-init netlify-env netlify-build netlify-build-preview netlify-build-branch netlify-redirects netlify-validate-config deploy-all check-hugo local-setup verify

# Default target
help:
	@echo "Hugo Blog Makefile Commands:"
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
	@echo "  make update-version     - Update Hugo to latest and sync version files"
	@echo "  make update             - Run all update commands"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make verify             - Run post-build SEO/analytics smoke tests"
	@echo "  make deploy-all         - Validate config, build, verify, and deploy to production"
	@echo "  make list               - List all content in the site"
	@echo "  make version            - Check Hugo version"
	@echo "  make local-setup        - Install/verify Hugo + initialize theme submodule"

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
clean:
	rm -rf $(PUBLIC_DIR)
	hugo --cleanDestinationDir --source $(HUGO_SITE_DIR)

# Build with minification
minify: check-hugo
	hugo --minify --source $(HUGO_SITE_DIR)

# Production build with all optimizations (matches netlify.toml production command)
production: check-hugo
	hugo --gc --minify --enableGitInfo --source $(HUGO_SITE_DIR)

# Deploy to Netlify production
netlify-deploy: check-hugo
	hugo --gc --minify --enableGitInfo --source $(HUGO_SITE_DIR)
	netlify deploy --prod

# Create Netlify deploy preview
netlify-preview: check-hugo
	hugo --gc --minify --buildFuture --source $(HUGO_SITE_DIR)
	netlify deploy

# Open Netlify site dashboard
netlify-open:
	netlify open

# Start Netlify dev environment
netlify-dev:
	netlify dev

# Show Netlify site status
netlify-status:
	netlify status

# Show Netlify deployment logs
netlify-logs:
	netlify sites:list
	@echo "Run 'netlify open:logs' to open logs in browser"

# Update Netlify CLI
netlify-update:
	npm update -g netlify-cli

# Initialize Netlify CLI with site
netlify-init:
	netlify init

# Show Netlify environment variables
netlify-env:
	netlify env:list

# Show Netlify redirect rules
netlify-redirects:
	@echo "Checking redirect rules from netlify.toml..."
	@grep -A 4 "redirects" netlify.toml
	@echo "\nVerify Obsidian notes redirect at: https://kakkoyun.me/notes/"

# Validate netlify.toml configuration
netlify-validate-config:
	@echo "Validating netlify.toml configuration..."
	@cat netlify.toml
	@echo "\nChecking Hugo version in netlify.toml matches local setup:"
	@grep -A 1 "HUGO_VERSION" netlify.toml | head -2
	@echo "Local Hugo version:"
	@hugo version
	@netlify sites:list
	@echo "\nConfig validation complete. If no errors appeared, your configuration is valid."

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
netlify-build:
	HUGO_VERSION=$(HUGO_VERSION) HUGO_ENV=production HUGO_ENABLEGITINFO=true netlify build

# Run Netlify deploy preview build locally
netlify-build-preview:
	HUGO_VERSION=$(HUGO_VERSION) netlify build --context deploy-preview

# Run Netlify branch deploy build locally
netlify-build-branch:
	HUGO_VERSION=$(HUGO_VERSION) netlify build --context branch-deploy

# List all content in the site
list: check-hugo
	hugo list all

# Check Hugo version
version: check-hugo
	hugo version

# Update commands
update: update-version theme-update

hugo-update:
	go install github.com/gohugoio/hugo@latest

theme-update:
	git submodule update --remote --merge

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

# Ensure Hugo exists & (optionally) matches pinned version
check-hugo:
	@V=$$(cat .hugo-version 2>/dev/null || echo ''); \
	if ! command -v hugo >/dev/null 2>&1; then \
	  echo "❌ Hugo not found"; \
	  if [ -n "$$V" ]; then \
	    echo "➡️  Installing Hugo via Go toolchain (version $$V)"; \
	    GO111MODULE=on go install github.com/gohugoio/hugo@v$$V || echo "⚠️ go install failed"; \
	  else \
	    echo "➡️  Installing latest Hugo via Go (no .hugo-version)"; \
	    GO111MODULE=on go install github.com/gohugoio/hugo@latest || echo "⚠️ go install failed"; \
	  fi; \
	fi; \
	if ! command -v hugo >/dev/null 2>&1; then \
	  if [ -n "$$V" ]; then \
	    echo "Manual install (extended Linux) options:"; \
	    echo "  curl -sSL https://github.com/gohugoio/hugo/releases/download/v$$V/hugo_extended_$$V_Linux-64bit.tar.gz | tar -xz hugo && chmod +x hugo && sudo mv hugo /usr/local/bin/"; \
	    echo "User-local:"; \
	    echo "  mkdir -p $$HOME/.local/bin && curl -sSL https://github.com/gohugoio/hugo/releases/download/v$$V/hugo_extended_$$V_Linux-64bit.tar.gz | tar -xz hugo && mv hugo $$HOME/.local/bin/"; \
	  else \
	    echo ".hugo-version not set; create it with desired version (e.g. echo 0.150.1 > .hugo-version)."; \
	  fi; \
	  exit 127; \
	fi; \
	REQ=$$(cat .hugo-version 2>/dev/null || echo ""); CUR=$$(hugo version 2>/dev/null | sed -n 's/.*v\([0-9][^ ]*\).*/\1/p'); \
	if [ -n "$$REQ" ] && [ -n "$$CUR" ] && [ "$$REQ" != "$$CUR" ]; then \
	  echo "⚠️  Hugo version mismatch: expected $$REQ, found $$CUR"; \
	else \
	  echo "✅ Hugo OK: $$(hugo version | awk '{print $$1,$$2}')"; \
	fi

local-setup: check-hugo ## Initialize local dev environment (Hugo + theme submodule + dry run)
	@echo "🔧 Local development environment setup"
	@echo "➡️  Ensuring theme submodule present..."
	@if [ ! -f themes/PaperMod/theme.toml ]; then \
	  git submodule update --init --recursive; \
	  echo "✅ Theme initialized"; \
	else \
	  echo "✅ Theme already present"; \
	fi
	@echo "➡️  Verifying Hugo can build (dry run)..."
	@hugo --quiet --renderToMemory || { echo "❌ Hugo build failed"; exit 1; }
	@echo "✅ Basic build succeeded"
	@echo "Next steps:"; \
	 echo "  make serve        # start dev server"; \
	 echo "  make serve-draft  # include drafts & future posts";
