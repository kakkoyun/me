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
make buffer-update      # Pull latest buffer-cli submodule
make humanizer-update   # Pull latest humanizer skill submodule
make vale-sync          # Fetch third-party Vale style packages (proselint, write-good)
make vale               # Run Vale prose linter on content/
make prose              # Alias for vale with a summary count
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
- `layouts/_default/list.html` -- Custom homepage with "Recent Notes" section; year-grouped section lists (`/posts/`, `/talks/`) via `GroupByDate "2006"` (home and term pages stay flat)
- `layouts/_default/list.md` -- Markdown alternate template for list/taxonomy pages (LLM-friendly output)
- `layouts/_default/single.md` -- Markdown alternate template for single posts (LLM-friendly output)
- `layouts/_default/_markup/render-image.html` -- Responsive images with WebP srcset generation
- `layouts/_default/_markup/render-blockquote.html` -- GitHub/Obsidian-style admonitions (see Admonitions under Content Conventions)
- `layouts/_partials/templates/schema_json.html` -- Rich JSON-LD `@graph` (home: WebSite+Person with sameAs; posts/newsletter: BlogPosting+BreadcrumbList; talks: Article; lists: CollectionPage). Replaces PaperMod's stock schema partial; deliberately emits no `articleBody`
- `layouts/partials/functions/link-index.html` -- Site-wide internal-link index built by scanning `.RawContent` (markdown links + reference definitions). **Contract: call only as `partialCached "functions/link-index.html" site`** — never with variant args, never as plain `partial`. Deliberately NOT a render hook, so rendered HTML/feeds stay byte-identical to stock output
- `layouts/partials/page-links.html` -- "Links to / Linked from" nav on posts/talks/newsletter singles, fed by the link index
- `layouts/_default/graph.html` + `layouts/_default/graph.json.json` -- `/graph/` content-graph page and its JSON endpoint (`/graph/index.json`); rendering via dependency-free canvas force sim in `assets/js/graph.js` (~4 KB minified, loads only on that page)
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
  - journal   # one of: journal, deep-dive, reflection, engineering, technical-findings, blogmentation
tags:
  - blog      # include "blog" tag by convention
  - topic-tag
cover:                        # optional
  image: /uploads/photo.jpeg
  alt: Descriptive alt text
  caption: Caption text
showToc: true                 # optional, for long technical posts
tocOpen: false                # optional
draft: true                   # for WIP content; use future publishDate for scheduled posts instead
promote: false                # optional; skip social-media promotion (defaults to promotable when omitted)
substack: false               # optional; exclude from the Substack syndication feed (included when omitted)
---
```

- Always include both `date` and `publishDate`
- `categories` is a single-value list
- For cross-posted content, add `showCanonicalLink: true` and `canonicalUrl:`
- For multi-part posts, add `series:` field with the human-readable series title (e.g., `series: "Fantastic Symbols and Where to Find Them"`)
- Do not quote scalar YAML values (dates, booleans) — only quote strings that contain special characters
- Use `draft: true` for WIP content; use a future `publishDate` (with `draft` omitted) for scheduled posts
- Set `promote: false` to publish a post but opt it out of the social-media promotion pipeline (`scripts/find-promotable-posts.sh`)
- Set `substack: false` to publish a post but exclude it from the Substack syndication feed (`/substack.xml`, see [docs/substack-syndication.md](docs/substack-syndication.md))

### Content Types

Each category has a distinct purpose, tone, and structure:

| Category | Purpose | Tone | Structure |
|---|---|---|---|
| `journal` | Conference recaps, event field notes, personal updates | Informal narrative | Intro → sections by day/topic → reflections |
| `deep-dive` | Long-form technical analysis (often cross-posted) | Technical, explanatory | Problem statement → technical walkthrough → conclusion |
| `reflection` | Career/personal essays, lessons learned | Introspective, narrative | Context/motivation → numbered lessons or reflections → takeaways |
| `engineering` | Talk companion articles, technical experiments | Technical with storytelling | Story hook → technical sections → benchmarks/experiments → conclusion |
| `technical-findings` | Tool evaluations, discovery write-ups | Evaluative, practical | Setup → evaluation sections → pros/cons → recommendations |
| `blogmentation` | Documentation-as-blog, how-to tutorials | Tutorial, step-by-step | Problem → solution with code snippets → results |

### Tag Conventions

- Always include `blog` as a tag on posts (every post in `content/posts/`)
- Use lowercase for new tags (`observability`, not `Observability`)
- Existing mixed-case tags (`eBPF`, `.Net`, `JVM`, `nodeJS`) are grandfathered — do not normalize them
- Talks always use `talks` as their first tag

### Filename Conventions

- Use kebab-case slugs: `fosdem-2026.md`, `ice-and-fire.md`
- Do not prefix with dates — the `2024-03-21-` prefix on one post is legacy, do not repeat it
- Multi-part posts: append `-part-2`, `-part-3` to the base slug (e.g., `fantastic-symbols-and-where-to-find-them-part-2.md`)

### Cover Image Conventions

- Blog posts: local images stored in `static/uploads/`, referenced as `/uploads/filename.jpeg`
- Talks: YouTube thumbnail URLs — `https://img.youtube.com/vi/{VIDEO_ID}/maxresdefault.jpg`
- Always include `alt` text; `caption` is optional

### Admonitions

GitHub-style alert blockquotes render as tinted admonition boxes with icons (types: `note`, `tip`, `important`, `warning`, `caution`):

```markdown
> [!NOTE]
> Body with **markdown**.

> [!tip] Custom Title
> Obsidian-style custom titles work too.
```

Rendered by `layouts/_default/_markup/render-blockquote.html`, styled in `assets/css/extended/admonitions.css` (light + dark). Regular blockquotes are unaffected. The raw syntax degrades gracefully on GitHub and in the `/index.md` markdown alternates.

### Talk Frontmatter

Talk titles are prefixed with `"talk: "`. Categories and first tag are always `talks`.

### Static Pages

Standalone pages (`about.md`, `now.md`, etc.) disable metadata display: `comments: false`, `disableShare: true`, `showWordCount: false`, `showReadingTime: false`.

## Prose Quality

Three layered defenses against AI-slop prose. All advisory; none block merges.

- **[REVIEW.md](REVIEW.md)** -- voice and prose-quality criteria. Companion to the Vale rules and the `prose-review.yml` workflow.
- **[.claude/skills/kemal-voice/SKILL.md](.claude/skills/kemal-voice/SKILL.md)** -- Anthropic-format skill. Auto-loads when editing files under `content/posts/`, `content/talks/`, `content/notes/`. Encodes tone, banned vocabulary, formulaic openers, patterns to scrutinize, and tone-by-category notes.
- **Vale** (`.vale.ini` + `styles/Slop/`) -- runs automatically on every content PR via `prose.yml` (reviewdog inline annotations). Run locally with `make vale`.
- **[.claude/commands/prose-review.md](.claude/commands/prose-review.md)** -- `/prose-review` slash command. Wraps the upstream `code-review` plugin with prose-specific priorities (banned vocab, formulaic openers, em-dash density, do-not-flag list, output format). Single source of truth for the procedure; `prose-review.yml` references it. Invoke locally as `/prose-review owner/repo/pull/N` to review a PR before merging.
- **[.claude/commands/capture.md](.claude/commands/capture.md)** -- `/capture blogmentation [topic]` to draft a short-form solution post (300-800 words, `categories: [blogmentation]`). Use `--weekly` to scan recent Claude Code sessions and surface candidates. Skill at `.agents/skills/blogmentation/SKILL.md`.
- **`prose-review.yml`** -- Claude prose reviewer. Triggered on demand by applying the `prose-review` label to a PR. Follows the procedure in `.claude/commands/prose-review.md` and pulls voice rules from `REVIEW.md` and the `kemal-voice` skill.
- **`claude-code-review.yml`** -- generic code reviewer. Triggered on demand by applying the `claude-review` label.

**Target tone:** clear, explanatory, fun, whimsical, honest, open. Take the technical material seriously; do not take yourself seriously. See `REVIEW.md` for the full description.

**Patterns to scrutinize, not preserve:** em-dash parenthetical asides (`— X —`), negative parallelism ("it's not X, it's Y" / "not just X, but Y"), and triadic rhythm all read as AI-flavored when overused. Vale flags the first two at `suggestion` (via `Slop.Density` and `Slop.Parallelism`). Triadic rhythm is review-by-eye. A single instance is fine; clusters are not.

**Before opening a PR with a new post:** run `make prose`. First-time setup: `brew install vale && make vale-sync`.

## CI/CD

GitHub Actions workflows:

- **`build.yml`** -- Build & verify on push/PR to master. Runs production build + `verify-build.sh`, then Lighthouse CI (Performance >= 85, Accessibility >= 90, Best Practices >= 90, SEO >= 90). Auto-creates GitHub issue if Lighthouse scores drop.
- **`links.yml`** -- Weekly + push/PR link checking via lychee. Excludes social platforms that block bots. Auto-creates issue on broken links.
- **`main.yml`** -- Daily cron updates `content/notes/_index.md` from Obsidian Publish RSS feed. Do not hand-edit the area between `<!-- NOTE-LIST:START -->` comment tags.
- **`deploy-scheduled.yml`** -- Daily cron at `00:10 UTC` (+ manual `workflow_dispatch`) that POSTs the Netlify build hook so **future-dated posts go live on their publish day**. The production build omits `--buildFuture` (see `netlify.toml`), so a post merged ahead of its `publishDate` stays hidden until a build runs at/after that date; a push to master only rebuilds when something is pushed, so this cron is what flips scheduled posts visible. A pre-flight `check` job runs `scripts/posts-publishing-today.sh` and skips the Netlify hook entirely when nothing is due, so the cron only consumes a build minute on a publishing day; `workflow_dispatch` bypasses the gate (the human pressing it has already decided). After triggering the build it verifies a *today-dated* post actually went live (same `scripts/posts-publishing-today.sh` + `scripts/check-post-live.sh`) rather than blindly sleeping — Netlify's atomic deploys keep the homepage at 200 off the old build, so reachability alone wouldn't prove freshness. Needs the `NETLIFY_BUILD_HOOK_URL` secret. Use the manual dispatch as a "publish now" button. **This is the publishing mechanism — promotion (below) no longer rebuilds.**
- **`lint.yml`** -- ShellCheck on `scripts/` and actionlint on workflows. Reviewdog-based PR annotations.
- **`prose.yml`** -- Vale prose lint on `content/**/*.md` PRs. Advisory (does not block). Auto-fires on content paths.
- **`prose-review.yml`** -- Claude prose review. Label-triggered only (apply `prose-review` to fire). Reads `REVIEW.md` and the `kemal-voice` skill. Advisory.
- **`claude-code-review.yml`** -- Generic code reviewer. Label-triggered only (apply `claude-review` to fire). Advisory.
- **`claude.yml`** -- `@claude` mention handler.
- **`merge-schedule.yml`** -- Auto-merges PRs containing a `/schedule YYYY-MM-DD` (or ISO 8601) directive in the description once the scheduled time has passed. Runs every 6 hours at `:30` plus on `pull_request` events. Used for **series posts** that cross-link each other: Hugo's `publishDate` controls visibility, but the PRs themselves must land on master in the intended order so internal links resolve. `require_statuses_success: true` waits for build + links + prose checks to go green before merging. Add `/schedule 2026-06-08T07:00:00Z` at the bottom of the PR description (ISO 8601 is timezone-safe). Failed merges get the `merge-schedule-failed` label. **Gotcha:** the action's directive parser uses the regex `/(^|\n)\/schedule/` and does **not** respect markdown code fences. Any line in the PR body starting with `/schedule ...` is treated as a directive, even inside a triple-backtick block. Wrap examples in list items (`- \`/schedule ...\``) or otherwise avoid line-starts.

## Key Integrations

- **Netlify:** Deployment platform. `/notes/*` is proxied (200 rewrite) to Obsidian Publish -- do not remove this redirect from `netlify.toml`. `static/_redirects` also exists for additional Netlify redirect rules; keep both files consistent.
- **Giscus:** Comments via GitHub Discussions on `kakkoyun/me`. Config in `config.yaml` under `params.giscus`.
- **Plausible + Hakanai:** Dual analytics. Extend via `params.analytics` in `config.yaml`.
- **Renovate:** Auto-updates Hugo version (in `.hugo-version` + `netlify.toml`), GitHub Actions, and PaperMod submodule.
- **Substack:** Blog posts are syndicated to Substack via a dedicated, Substack-tuned RSS feed at `/substack.xml` (output format `substack` in `config.yaml`, template `layouts/index.substack.xml`). Hugo stays canonical; Substack is a one-directional mirror you feed via `Settings → Import`. The feed emits full-text `<content:encoded>` with absolutised image/link URLs and a top "Originally published at" backlink (Substack supports no canonical tag). Opt a post out with `substack: false`. Setup and post-import steps are in [docs/substack-syndication.md](docs/substack-syndication.md).

## Buffer CLI Integration

Social media scheduling via [erickhun/buffer-cli](https://github.com/erickhun/buffer-cli), installed as a git submodule at `tools/buffer-cli/`.

- **Binary:** `~/.local/bin/buffer-cli` (raw upstream binary, macOS ARM64)
- **Wrapper:** `scripts/buffer` → injects `BUFFER_AUTH_TOKEN` from 1Password (`op://Private/Buffer API Token/credential`), then execs `buffer-cli`
- **PATH entry:** `~/.local/bin/buffer` → symlink to `scripts/buffer`
- **Skill:** `~/.claude/skills/buffer/SKILL.md` → global symlink to `tools/buffer-cli/.claude/skills/skill.md` (auto-updates with `make buffer-update`; invoke via `/buffer` in any Claude Code session)
- **1Password:** Token stored at `op://Private/Buffer API Token/credential` in the Personal account (Private vault)

The wrapper pattern means the upstream skill's `buffer get-account` / `buffer post` calls work unmodified. In CI, set `BUFFER_AUTH_TOKEN` directly as an environment variable to skip the `op read` call.

### Social Media Promotion Pipeline

Automated via `.github/workflows/promote-post.yml` with two triggers:

- **Nightly cron (6 AM UTC)**: promotes posts on their publish day (`publishDate == today`)
- **Manual dispatch**: the "promote now" button — give a `post_path` to promote one
  specific post, or leave it blank to promote everything due today

There is **no push trigger**: `claude-code-action` rejects the `push` event type
("Unsupported event type: push"), so promotion runs only on supported automation
events (`schedule`, `workflow_dispatch`). A post merged on its publish day *after*
the 6 AM cron has run won't be auto-promoted that day — use the manual dispatch to
promote it immediately.

Promotion does **not** rebuild the site — publishing is owned by `deploy-scheduled.yml`
(00:10 UTC). The 6 AM promotion cron is deliberately later so the post is already live.
Before posting, a **liveness guard** (`Verify posts are live`) maps each candidate to its
public URL (`content/posts/<slug>.md` → `/posts/<slug>/`) and polls it; a post that is not
reachable is dropped with a warning, so promotion never posts a link to a 404.

All date/draft validation is deterministic bash in `scripts/find-promotable-posts.sh`.
Claude handles only the creative work: reading the post, crafting messages, posting to Buffer.

Posts go to Twitter + LinkedIn + Bluesky. Twitter/Bluesky use threads (message + link).
LinkedIn includes the link in the main post body.

Two skills shape the writing and are wired into both the local command and the CI workflow:

- **`kemal-voice`** (`.claude/skills/kemal-voice/SKILL.md`) — author voice, banned vocabulary, formulaic openers, patterns to scrutinize. Applied while drafting.
- **`humanizer`** (`.claude/skills/humanizer/SKILL.md`) — AI-pattern detector from [blader/humanizer](https://github.com/blader/humanizer), vendored as a git submodule at `tools/humanizer/` with `.claude/skills/humanizer` as a symlink. Applied as a revision pass after drafting. The CI workflow initialises just this submodule (`tools/humanizer`) before the action runs; sync locally with `make humanizer-update`.

Local: `/project:promote-post content/posts/<slug>.md` in any Claude Code session.

## Commit Style

Prefix with content type when relevant: `post: add profiling guide`, `layout: fix mobile nav`, `ci: update lighthouse thresholds`. Do not mix theme overrides with new articles in the same commit. Minimize JS additions -- the site favors a minimal JS footprint.
