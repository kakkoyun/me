# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hugo static site (personal blog) using PaperMod theme, deployed to Netlify. Published at https://kakkoyun.me. Hugo version is pinned in `.hugo-version` and mirrored in `netlify.toml`.

## Build Commands

```bash
make serve              # Local dev server (fast render disabled)
make serve-draft        # Dev server with drafts and future-dated posts
make production         # Production build: hugo --gc --minify --enableGitInfo
make clean              # Remove public/ and clean destination
make verify             # Post-build SEO/analytics smoke tests (scripts/verify-build.sh)
make deploy-all         # Full pipeline: validate + clean + build + verify + deploy
make netlify-preview    # Preview build with future posts included
make local-setup        # First-time setup: install Hugo, init submodule, dry-run build
make check-hugo         # Verify Hugo version matches .hugo-version (auto-installs via Go)
make update-version     # Update Hugo to latest, sync .hugo-version + netlify.toml
make theme-update       # Pull latest PaperMod theme submodule
```

## Architecture

- **Theme:** PaperMod git submodule at `themes/PaperMod/`. Never edit theme files directly; override via `layouts/` or `assets/css/extended/`.
- **Config:** Single `config.yaml` (not `hugo.toml`). All site params, menus, taxonomies, analytics, and comments config live here.
- **Content:** Flat markdown files in `content/posts/`, `content/talks/`, `content/notes/`, plus standalone pages (`about.md`, `now.md`, etc.).
- **Images:** Stored in `static/uploads/` and referenced as `/uploads/filename.jpeg`. No page bundles currently used.
- **Output:** `public/` is the build output (gitignored, never commit edits there).

### Layout Overrides (over PaperMod)

- `layouts/partials/extend_head.html` -- Injects markdown alternate links, Plausible analytics, Hakanai tracker
- `layouts/partials/header.html` -- Custom mobile hamburger menu (replaces PaperMod default)
- `layouts/partials/comments.html` -- Giscus (GitHub Discussions) comment integration
- `layouts/partials/home_info.html` -- Custom homepage info block (overrides PaperMod default)
- `layouts/partials/author.html` -- Custom author bio partial
- `layouts/_default/list.html` -- Custom homepage with "Recent Notes" section
- `layouts/_default/list.md` -- Markdown alternate template for list/taxonomy pages (LLM-friendly output)
- `layouts/_default/single.md` -- Markdown alternate template for single posts (LLM-friendly output)
- `layouts/_default/_markup/render-image.html` -- Responsive images with WebP srcset generation
- `layouts/robots.txt` -- Explicitly welcomes AI crawlers, references llms.txt

### Custom Shortcodes

- `{{< sidenote >}}content{{< /sidenote >}}` -- Tufte-style margin notes (params: `side`, `label`, `id`)
- `{{< tooltip "Term" >}}definition{{< /tooltip >}}` -- CSS-only hover tooltips (params: `term`, `placement`)
- Styles in `assets/css/extended/sidenotes-tooltips.css`

### LLM-Friendly Output

Every page generates a markdown alternate (`index.md` appended to any URL) via `layouts/_default/single.md` and `list.md`. `static/llms.txt` is a committed static file (not generated). The `robots.txt` explicitly allows AI crawlers (GPTBot, Claude-Web, etc.).

## Content Conventions

### Blog Post Frontmatter

```yaml
---
title: "Post Title"
description: "One-sentence description."
date: 2026-02-13T00:00:00Z
publishDate: 2026-02-13T00:00:00Z
categories:
  - journal   # one of: journal, deep-dive, reflection, technical-findings, blogmentation
tags:
  - blog      # include "blog" tag by convention
  - topic-tag
cover:                        # optional
  image: /uploads/photo.jpeg
  alt: Descriptive alt text
  caption: Caption text
showToc: true                 # optional, for long technical posts
tocOpen: false                # optional
draft: true                   # for WIP content
---
```

- Always include both `date` and `publishDate`
- `categories` is a single-value list
- For cross-posted content, add `showCanonicalLink: true` and `canonicalUrl:`
- For multi-part posts, add `series:` field

### Talk Frontmatter

Talk titles are prefixed with `"talk: "`. Categories and first tag are always `talks`.

### Static Pages

Standalone pages (`about.md`, `now.md`, etc.) disable metadata display: `comments: false`, `disableShare: true`, `showWordCount: false`, `showReadingTime: false`.

## CI/CD

Three GitHub Actions workflows:

- **`build.yml`** -- Build & verify on push/PR to master. Runs production build + `verify-build.sh`, then Lighthouse CI (Performance >= 85, Accessibility >= 90, Best Practices >= 90, SEO >= 90). Auto-creates GitHub issue if Lighthouse scores drop.
- **`links.yml`** -- Weekly + push/PR link checking via lychee. Excludes social platforms that block bots. Auto-creates issue on broken links.
- **`main.yml`** -- Daily cron updates `content/notes/_index.md` from Obsidian Publish RSS feed. Do not hand-edit the area between `<!-- NOTE-LIST:START -->` comment tags.

## Key Integrations

- **Netlify:** Deployment platform. `/notes/*` is proxied (200 rewrite) to Obsidian Publish -- do not remove this redirect from `netlify.toml`. `static/_redirects` also exists for additional Netlify redirect rules; keep both files consistent.
- **Giscus:** Comments via GitHub Discussions on `kakkoyun/me`. Config in `config.yaml` under `params.giscus`.
- **Plausible + Hakanai:** Dual analytics. Extend via `params.analytics` in `config.yaml`.
- **Renovate:** Auto-updates Hugo version (in `.hugo-version` + `netlify.toml`), GitHub Actions, and PaperMod submodule.

## Commit Style

Prefix with content type when relevant: `post: add profiling guide`, `layout: fix mobile nav`, `ci: update lighthouse thresholds`. Do not mix theme overrides with new articles in the same commit. Minimize JS additions -- the site favors a minimal JS footprint.
