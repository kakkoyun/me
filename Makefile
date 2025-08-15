# Hugo blog Makefile
# Common commands for blog management and Netlify deployment

# Variables
HUGO_SITE_DIR := .
PUBLIC_DIR := public
HUGO_VERSION := 0.148.2  # Match netlify.toml HUGO_VERSION

.PHONY: build serve serve-draft clean minify production netlify-deploy netlify-preview netlify-open list version netlify-update netlify-dev netlify-status netlify-logs netlify-init netlify-env netlify-build netlify-build-preview netlify-build-branch netlify-redirects netlify-validate-config deploy-all

# Default target
help:
	@echo "Hugo Blog Makefile Commands:"
	@echo "  make build              - Build the site"
	@echo "  make serve              - Run local development server"
	@echo "  make serve-draft        - Run local server with drafts enabled"
	@echo "  make clean              - Remove generated files"
	@echo "  make minify             - Build with minification enabled"
	@echo "  make production         - Build for production with all optimizations"
	@echo "  make netlify-deploy     - Deploy to Netlify production"
	@echo "  make netlify-preview    - Create Netlify deploy preview"
	@echo "  make netlify-open       - Open Netlify site dashboard"
	@echo "  make netlify-dev        - Start Netlify dev environment"
	@echo "  make netlify-status     - Show Netlify site status"
	@echo "  make netlify-logs       - Show Netlify deployment logs"
	@echo "  make netlify-build      - Run Netlify production build locally"
	@echo "  make netlify-build-preview - Run Netlify preview build locally"
	@echo "  make netlify-init       - Initialize Netlify CLI"
	@echo "  make netlify-env        - Show Netlify environment variables"
	@echo "  make netlify-redirects  - Show Netlify redirect rules"
	@echo "  make netlify-validate-config - Validate netlify.toml configuration"
	@echo "  make netlify-update     - Update Netlify CLI"
	@echo "  make deploy-all         - Validate config, build, and deploy to production"
	@echo "  make list               - List all content in the site"
	@echo "  make version            - Check Hugo version"

# Build the site
build:
	hugo --source $(HUGO_SITE_DIR)

# Run development server (without drafts)
serve:
	hugo server --source $(HUGO_SITE_DIR) --disableFastRender

# Run development server with drafts
serve-draft:
	hugo server --source $(HUGO_SITE_DIR) --buildDrafts --buildFuture --disableFastRender

# Clean generated files
clean:
	rm -rf $(PUBLIC_DIR)
	hugo --cleanDestinationDir --source $(HUGO_SITE_DIR)

# Build with minification
minify:
	hugo --minify --source $(HUGO_SITE_DIR)

# Production build with all optimizations (matches netlify.toml production command)
production:
	hugo --gc --minify --enableGitInfo --source $(HUGO_SITE_DIR)

# Deploy to Netlify production
netlify-deploy:
	hugo --gc --minify --enableGitInfo --source $(HUGO_SITE_DIR)
	netlify deploy --prod

# Create Netlify deploy preview
netlify-preview:
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

# All-in-one deployment command
deploy-all: netlify-validate-config clean production
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
list:
	hugo list all

# Check Hugo version
version:
	hugo version
