# Substack syndication

Blog posts are syndicated to Substack as a mirror. **Hugo stays the canonical
source of truth**; Substack is a one-directional, lossy copy. Never edit a post
on Substack and expect it to flow back — the canonical text lives in
`content/posts/`.

The Hugo side is fully automated by a dedicated feed; the Substack side is
manual because Substack has no public publishing API and its native importer is
a one-time/manual operation.

## What Hugo generates

A Substack-tuned RSS feed is published at **`https://kakkoyun.me/substack.xml`**.

- **Output format:** `substack` (defined in `config.yaml`, added to `outputs.home`).
- **Template:** `layouts/index.substack.xml`.
- **Scope:** blog posts only (`content/posts`). Drafts and future-dated posts are
  excluded by the production build; opt a specific post out with `substack: false`
  in its frontmatter (mirrors `promote: false`). The shared `hiddenInRss: true`
  flag also excludes a post.
- **No item limit:** the whole eligible archive is in the feed, so the first
  import can backfill everything in one pass.

It differs from the generic `/index.xml` feed in three ways, each compensating
for a Substack importer limitation:

1. **Absolute URLs.** Substack does not re-host root-relative images
   (`/uploads/...`) or resolve relative internal links. The template absolutises
   every `href`/`src`/`srcset` against `https://kakkoyun.me`.
2. **Original-post backlink.** Each post body starts with an italic
   "Originally published at kakkoyun.me" link to the canonical URL.
3. **SEO attribution.** Substack supports **no** canonical tag (neither automatic
   nor manual), so the backlink above is the only attribution mechanism. Modern
   search engines are lenient about same-author duplicate content, so a body
   backlink is sufficient.

## One-time setup

1. In Substack: **Settings → Import** (a.k.a. Import/Export → Import posts).
2. Paste the feed URL: `https://kakkoyun.me/substack.xml`.
3. If Substack offers an **import-as-draft** toggle, use it — it lets you eyeball
   formatting before sending to subscribers. If it offers **ongoing import**,
   enable it so new posts flow in automatically. (Both options are
   importer-version dependent and not guaranteed; fall back to a periodic manual
   re-run of the import if ongoing import isn't available.)
4. The first run pulls the full archive. If Substack caps a single run, re-run
   the import or use Substack's one-time URL-paste import for the remainder.

## Post-import checklist (the lossy parts Substack owns)

The importer mangles things the feed can't fix. After each import, before
publishing/sending on Substack:

- **Images:** confirm every image rendered. Substack's image import is
  unreliable; re-upload any that 404 to Substack's media library.
- **Shortcodes:** the rendered HTML for `{{< sidenote >}}` / `{{< tooltip >}}`
  (an `<aside>` / `<span class>`) is stripped by Substack to plain text. Only one
  post currently uses these; reformat by hand if needed.
- **Footnotes:** not converted to Substack footnotes; clean up if present.
- **Backlink:** confirm the "Originally published at" line survived at the top.

## Re-import caution

Treat import as **additive**. Re-importing the same post may create a duplicate
rather than update the existing one (Substack's dedupe behaviour is
undocumented). After a post is imported, manage any further edits directly in
Substack — don't re-import it.

## Verifying the feed locally

```bash
make production                       # or: hugo --gc --minify
xmllint --noout public/substack.xml   # valid XML
grep -c '<content:encoded>' public/substack.xml          # full bodies present
grep -c 'kakkoyun.mehttps://' public/substack.xml        # must be 0 (no doubled domain)
grep -oE 'src="/[^"]*' public/substack.xml | grep -v https  # must be empty (no relative src)
```
