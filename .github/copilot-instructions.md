# Copilot Project Instructions

Purpose: This repo builds the personal static site (Hugo + PaperMod submodule) deployed to Netlify. Optimize for fast, accessible, content-focused iteration while preserving existing conventions.

## Architecture & Key Paths
- Static site generator: Hugo (version pinned in `.hugo-version`, mirrored in `netlify.toml`).
- Theme: Git submodule at `themes/PaperMod/` – never edit theme files directly; override via `layouts/` or `assets/`.
- Content roots: `content/posts/`, `content/notes/`, `content/talks/`, plus single pages (`about.md`, `archives.md`, etc.).
- Custom layouts: `layouts/_default/`, partials in `layouts/partials/` (e.g. `extend_head.html`, `comments.html`).
- Generated output: `public/` (DO NOT commit manual edits there).
- Automation: GitHub Action `.github/workflows/main.yml` updates `content/notes/_index.md` from external feed.

## Build & Run Workflow
- Local dev (fast render disabled intentionally): `make serve` or with drafts/future-dated content: `make serve-draft`.
- Production-equivalent build: `make production` (gc + minify + git info) – matches Netlify.
- One-shot deploy (validate + build + deploy): `make deploy-all`.
- Netlify preview style build (future posts included): `make netlify-preview`.
- Update Hugo & propagate version to `netlify.toml`: `make update-version`.
- Update theme submodule: `make theme-update` (commit resulting changes).

## Content Conventions
- Blog post filenames: `YYYY-MM-DD-slug.md` in `content/posts/`.
- Use front matter fields: `title`, `date`, `draft`, `description`, `tags`, `categories`, `lastmod`, `toc` (true for long technical posts).
- Taxonomy names (from `config.yaml`): categories → `categories`, tags → `tags`, series → `series`.
- Humor + technical tone is intentional; keep accuracy while preserving personality.
- For posts needing images or multiple assets, prefer page bundles (folder with `index.md`).
- Highlight code fences with language; Hugo highlighting is configured (monokai, line numbers on).

## Layout / Theming Overrides
- Add/modify head elements in `layouts/partials/extend_head.html`.
- Comments use giscus: respect `params.giscus` config; if adjusting mapping or theme, update `config.yaml` only.
- To change list or single page rendering, edit or add templates under `layouts/_default/` (avoid modifying theme directly).

## Performance & Accessibility (from existing rules)
- Optimize images before adding (choose JPEG/PNG/WebP appropriately). Place under `static/img/` or bundle-specific folder.
- Use `figure` shortcode or `{{< highlight >}}` for advanced code formatting.
- Always supply meaningful alt text; maintain heading hierarchy (no skipping levels).
- Avoid inline styling—prefer theme parameters or partial overrides.

## Integrations & Analytics
- Analytics: Plausible (`params.analytics.plausible`) + Hakanai; if adding a new provider, extend `params.analytics` in `config.yaml`.
- Social + edit links controlled via `params.socialIcons` and `params.editPost`.
- Obsidian notes reverse proxy redirect lives in `netlify.toml` (`/notes/*`); be careful not to unintentionally override.

## Automation & Generated Content
- Do not hand-edit the notes list area guarded by the GitHub Action comment tags in `content/notes/_index.md`.
- Never commit transient local build artifacts besides intended submodule or content changes.

## Safe Update Pattern
1. Pull & init submodules: `git submodule update --init --recursive`.
2. Branch, make content/layout change.
3. Run `make serve` to preview; for production parity run `make production` locally.
4. If Hugo upgraded: run `make update-version` then commit `.hugo-version` + `netlify.toml` diff.
5. Commit with concise message (prefix with content type when relevant, e.g., `post: add profiling guide`).

## PR Guidance for Agents
- Group related content edits; avoid mixing theme overrides with new articles in same commit.
- For layout changes, include before/after rationale in PR description (focus on accessibility/performance impact).
- Do not introduce JS unless justified (site favors minimal JS footprint).

## Examples
- New post skeleton (draft): see existing in `content/posts/2024-03-21-vibe-coding-with-cursor.md` for style & tone.
- Talk entry pattern: see `content/talks/*.md` and taxonomies under `public/categories/talks/` (generated reference only).

If anything here seems ambiguous (e.g., adding a new shortcode, expanding analytics), surface a clarifying question before implementing.
