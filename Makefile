# Hugo blog Makefile
# Common commands for blog management and Netlify deployment

# Variables
HUGO_SITE_DIR := .
PUBLIC_DIR := public

.PHONY: build serve serve-draft clean minify production netlify-deploy netlify-preview netlify-open list version netlify-update netlify-dev netlify-status netlify-logs

# Default target
help:
	@echo "Hugo Blog Makefile Commands:"
	@echo "  make build           - Build the site"
	@echo "  make serve           - Run local development server"
	@echo "  make serve-draft     - Run local server with drafts enabled"
	@echo "  make clean           - Remove generated files"
	@echo "  make minify          - Build with minification enabled"
	@echo "  make production      - Build for production with all optimizations"
	@echo "  make netlify-deploy  - Deploy to Netlify production"
	@echo "  make netlify-preview - Create Netlify deploy preview"
	@echo "  make netlify-open    - Open Netlify site dashboard"
	@echo "  make netlify-dev     - Start Netlify dev environment"
	@echo "  make netlify-status  - Show Netlify site status"
	@echo "  make netlify-logs    - Show Netlify deployment logs"
	@echo "  make netlify-update  - Update Netlify CLI"
	@echo "  make list            - List all content in the site"
	@echo "  make version         - Check Hugo version"

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

# Production build with all optimizations
production:
	hugo --minify --gc --ignoreCache --source $(HUGO_SITE_DIR)

# Deploy to Netlify production
netlify-deploy:
	hugo --minify --gc
	netlify deploy --prod

# Create Netlify deploy preview
netlify-preview:
	hugo --minify --gc
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

# List all content in the site
list:
	hugo list all

# Check Hugo version
version:
	hugo version