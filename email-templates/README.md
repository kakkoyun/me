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
2. Preview/validate. Easiest option is the official MJML CLI:

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

## Templates

- [`standard.mjml`](standard.mjml) — the main broadcast template, used
  by both the blog-wide main feed and per-publication campaigns (Reads
  & Builds and any future ones). One template so the visual identity
  stays consistent across all newsletters.

If a campaign ever needs a meaningfully different layout, fork
`standard.mjml` to e.g. `reads-and-builds.mjml` rather than branching
inside a single template.

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
| `{{description}}` (inside articles) | Article description / summary |
| `{{{link}}}` (inside articles) | Article URL — note the triple braces |

Use triple-brace `{{{ }}}` around URLs to skip HTML-escaping; Mustache
treats triple-brace output as raw.

If Hakanai exposes additional variables (a `socials` dict, custom
campaign fields, etc.) consult their docs at
<https://hakanai.io/docs/broadcast/emails>.

## Theme alignment

Hardcoded hex values in the templates mirror PaperMod's light-theme
tokens from
[`themes/PaperMod/assets/css/core/theme-vars.css`](../themes/PaperMod/assets/css/core/theme-vars.css).

| PaperMod token | Email hex |
| --- | --- |
| `--primary` (emphasis, headings, links) | `#1E1E1E` |
| `--content` (body text) | `#1F1F1F` |
| `--secondary` (muted text, footer) | `#6C6C6C` |
| `--border` (subtle dividers) | `#EEEEEE` |
| `--tertiary` (slightly stronger dividers) | `#D6D6D6` |
| `--theme` (content card background) | `#FFFFFF` |
| Outer page wash | `#FAFAFA` |

If PaperMod's palette changes, update the constants in `standard.mjml`
to match.

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

When you change socials, update both:

- `config.yaml` (website footer)
- `standard.mjml` (email footer)
