# Email templates

Source-of-truth [MJML](https://mjml.io) templates for the
[Hakanai Broadcast](https://hakanai.io/docs/broadcast) newsletter campaigns
that power email delivery on `kakkoyun.me`.

These files live in git so:

- Edits are reviewable in pull requests instead of vanishing into the
  Hakanai dashboard.
- The styling stays close to the Hugo theme (PaperMod) by pulling from
  the same colour tokens.
- A second person (or future me) can rebuild the template if Hakanai's
  copy is lost.

## Workflow

1. Edit the `.mjml` file locally.
2. Validate with `make email-validate`. This runs the official MJML
   compiler in strict mode and additionally checks for the
   Mustache-in-HTML-comment pitfall described below.

   To preview the rendered HTML in a browser:

   ```sh
   npx mjml standard.mjml -o /tmp/standard.html && open /tmp/standard.html
   ```

   Or paste into the browser-based editor at
   <https://mjml.io/try-it-live>.
3. When happy, paste the **MJML source** into Hakanai's template editor
   (Settings → Newsletter → Email template). Hakanai compiles MJML and
   substitutes the Mustache variables at broadcast time, so you don't
   need to upload compiled HTML.
4. Commit the `.mjml` change. Do not commit compiled HTML to this repo.

CI runs `make email-validate` on every PR that touches
`templates/emails/` ([workflow](../../.github/workflows/email-templates.yml)).

### Mustache tokens are not allowed inside HTML comments

Hakanai's pre-processor isn't comment-aware. A token like
`{{description}}` mentioned inside an `<!-- ... -->` block (e.g. in a
documentation comment) gets substituted with the actual article body
HTML at send time. If that body contains a `-->` --- or any number of
other tokens that confuse MJML's strict parser --- the template
rendering breaks with the unhelpful dashboard error *"Error when
rendering or saving template: Error:"*.

Keep all documentation in this README, not inline in the `.mjml`
files. The validator's `mustache-in-comments` check fails the build
if a Mustache token slips into a comment.

## Templates

- [`standard.mjml`](standard.mjml) — **digest** layout. Used by the
  blog-wide main feed campaign. Hakanai aggregates the recent RSS
  items into one email; the `{{#articles}}` block renders each item
  as a title + summary card.
- [`the-unwind.mjml`](the-unwind.mjml) — **single-article** layout.
  Used by The Unwind, the hand-curated weekly publication. Hakanai
  is configured to send one email per new RSS item, so the
  `{{#articles}}` block iterates once and the full HTML body of
  the issue is dropped in via `{{{description}}}` (triple-brace,
  raw HTML) inside an `<mj-text mj-class="article-body">` wrapper.

  Article content inherits styling from the body-default `mj-text`
  attributes (system font, 16px, line-height 1.6). For now the
  template intentionally keeps the `<mj-style>` block tiny — we
  arrived at this minimal-diff variant after Hakanai rejected an
  earlier, more elaborate version (with `<mj-raw>`, an
  `letter-spacing`/`text-transform` mj-class, a per-article
  two-section layout, and a long `.article-body h2 / p / a /
  blockquote / pre / code / img / hr` selector list in
  `<mj-style>`). Re-introduce styling rules incrementally if needed,
  running `make email-validate` then paste-testing in the dashboard
  between additions to find what Hakanai actually rejects.

If another campaign needs a meaningfully different layout, fork
whichever template is closer rather than branching inside one.

## Hakanai Mustache variables

Interpolated by Hakanai at send time. Values come from the campaign
configuration plus the RSS items being broadcast.

| Variable | Meaning |
| --- | --- |
| `{{title}}` | Email title (used in `<title>` / subject in some contexts) |
| `{{newsletter.name}}` | Display name of the newsletter |
| `{{newsletter.url}}` | URL configured for the newsletter |
| `{{newsletter.unsubscribe}}` | Auto-generated unsubscribe link |
| `{{currentYear}}` | Current year, for copyright lines |
| `{{#articles}}…{{/articles}}` | Section/loop over items in the broadcast |
| `{{title}}` (inside articles) | Article title |
| `{{description}}` (inside articles) | Article description / summary. See note below for full-body templates. |
| `{{{link}}}` (inside articles) | Article URL — note the triple braces |
| `{{pubDate}}` (inside articles) | Article publication date, formatted by Hakanai |

Use triple-brace `{{{ }}}` around URLs and HTML to skip HTML-escaping;
Mustache treats triple-brace output as raw.

### Article body for full-content templates

`the-unwind.mjml` needs the **full HTML body** of an issue, not the
short summary. The site's RSS template (`layouts/_default/rss.xml`)
emits two body fields per item:

- `<description>` — `.Description` (frontmatter) or `.Summary` (auto)
- `<content:encoded>` — full HTML when `params.showFullTextinRSS:
  true` (it is)

Which one Hakanai surfaces inside `{{#articles}}` as `{{description}}`
isn't documented in a way I can verify (sandbox blocked from
`hakanai.io`). The template uses `{{{description}}}`; if the preview
shows only the summary, switch to whichever variable holds
`content:encoded` (likely `{{{contentEncoded}}}` or `{{{content}}}`),
or override the section's RSS template to put `.Content` into
`<description>`.

If Hakanai exposes additional variables (a `socials` dict, custom
campaign fields, etc.) consult their docs at
<https://hakanai.io/docs/broadcast/emails>.

## Theme alignment

Hardcoded hex values in the templates mirror PaperMod's light-theme
tokens from
[`themes/PaperMod/assets/css/core/theme-vars.css`](../../themes/PaperMod/assets/css/core/theme-vars.css).

| PaperMod token | Email hex |
| --- | --- |
| `--primary` (emphasis, headings, links) | `#1E1E1E` |
| `--content` (body text) | `#1F1F1F` |
| `--secondary` (muted text, footer) | `#6C6C6C` |
| `--border` (subtle dividers) | `#EEEEEE` |
| `--tertiary` (slightly stronger dividers) | `#D6D6D6` |
| `--theme` (content card background) | `#FFFFFF` |
| Outer page wash | `#FAFAFA` |

If PaperMod's palette changes, update the constants in both
`standard.mjml` and `the-unwind.mjml` to match.

Email-client dark mode is intentionally not implemented yet — Apple
Mail respects `prefers-color-scheme`, but Gmail and Outlook ignore it,
so the inconsistent result is worse than the all-light version.
Revisit if subscribers ask.

## Social links

The footer uses a hardcoded subset of the socials configured in
`config.yaml` under `params.socialIcons`. We intentionally don't use
Hakanai's `{{#socials.X}}` template blocks even though the example
template does — that lets us keep the canonical list in this repo and
avoid having to keep two lists in sync.

When you change socials, update all three:

- `config.yaml` (website footer)
- `standard.mjml` (digest email footer)
- `the-unwind.mjml` (single-article email footer)
