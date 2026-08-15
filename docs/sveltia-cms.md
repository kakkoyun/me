# Sveltia CMS

[Sveltia CMS](https://github.com/sveltia/sveltia-cms) is a Git-based content
editor — a maintained replacement for Netlify/Decap CMS. It edits the markdown
in `content/` directly and commits to GitHub. There is no database and no
running server: the admin page is static, the browser talks to the GitHub API,
and Hugo stays the source of truth.

The CMS is a convenience layer over `git commit`. Anything it does, you can do
by editing the markdown by hand.

## Where it lives

Two hand-maintained files. No Hugo module, no npm dependency, no build step.

| File | Purpose |
| --- | --- |
| `static/admin/index.html` | Loads the CMS bundle from unpkg at a pinned version |
| `static/admin/config.yml` | Backend, collections, and field definitions |

Hugo copies `static/` verbatim, so the editor is served at
`https://kakkoyun.me/admin/`. The page carries `<meta name="robots"
content="noindex">` and `layouts/robots.txt` adds `Disallow: /admin/`.

## Auth

Three pieces, each configured once:

1. **GitHub OAuth app** (github.com → Settings → Developer settings → OAuth
   Apps). Holds the client ID and secret. Its callback URL points at Netlify's
   OAuth gateway, not at this site.
2. **Netlify OAuth provider** (Netlify → Site settings → Access control →
   OAuth). The GitHub client ID and secret are pasted here. Netlify runs the
   token exchange so the secret never reaches the browser.
3. **`backend:` in `config.yml`.** Names the repo and branch. No `base_url` —
   Netlify's gateway is the default for sites hosted on Netlify, so pointing at
   it explicitly would be redundant.

Signing in requires push access to `kakkoyun/me`. There is no separate CMS user
list; GitHub permissions are the permissions.

Commits made through the CMS use the `commit_messages` templates in
`config.yml`, so they land as `post: create <slug>` and match the repo's commit
style.

### Rotating credentials

If the client secret leaks, or on a routine rotation:

1. GitHub → the OAuth app → **Generate a new client secret**.
2. Netlify → Site settings → Access control → OAuth → paste the new secret.
3. Delete the old secret on GitHub.

No code change and no deploy. The client ID stays the same unless you replace
the whole OAuth app. Existing editor sessions keep working until their token
expires.

## Risk 1: the CMS drops undeclared frontmatter keys

**This is the one failure mode worth internalising.**

Sveltia only serializes fields it knows about. Open a post in the CMS, change
one word, hit save, and every frontmatter key missing from `config.yml` is gone
from the committed file. No warning, no error — the key is simply absent from
the diff.

For this site that would mean silently losing `promote: false`, `substack:
false`, `canonicalUrl`, `series`, or `hiddenInRss` — flags that control
syndication and promotion. A post could start promoting itself because a
`promote: false` vanished during an unrelated typo fix.

**So: any new frontmatter key must also be declared in
`static/admin/config.yml`.** Declaring it as `widget: hidden` is enough — that
keeps it out of the editor UI while still round-tripping it through save:

```yaml
- name: myNewKey
  widget: hidden
```

Use `widget: hidden` (rather than a real widget) for flags whose *absence* is
meaningful. `promote` and `substack` both work that way: omitted means yes,
`false` means opt out. A `widget: boolean` would write `false` into every post
that never set the field, quietly making the whole archive non-promotable.

## The guard: `scripts/check-cms-fields.sh`

Because the failure is silent, it is enforced in CI rather than trusted to
memory. The script reads every frontmatter key in the CMS-managed content
directories and asserts each one is declared somewhere in `config.yml`.

```bash
bash scripts/check-cms-fields.sh
```

It also runs as part of `make test`, which `lint.yml` runs on every PR.

A failure looks like this:

```
UNDECLARED: 'newKey' found in posts/ but not in .../static/admin/config.yml

Add the missing key(s) as 'widget: hidden' fields in .../static/admin/config.yml
to prevent Sveltia CMS from silently dropping them on save.
```

The fix is always the same: add the key to `config.yml`. Do not delete the key
from the post to make the check pass.

Two env vars tune it, mostly for testing:

- `CMS_CONFIG` — path to the config (default `static/admin/config.yml`)
- `CMS_CONTENT_DIRS` — colon-separated dirs to scan (default `content/posts`)

## Bumping the CMS version

`static/admin/index.html` pins an exact version *and* the subresource integrity
hash of that exact file:

```html
<script
  src="https://unpkg.com/@sveltia/cms@0.191.0/dist/sveltia-cms.js"
  integrity="sha384-vqs7J70ghmeGaGfUXWfvUK3kj+ssanA2dTEA5Uvu977zhm9tZzRB45Bz7wXO0Oux"
  crossorigin="anonymous"
></script>
```

**The version and the hash are one unit.** Change one without the other and the
browser computes a digest that does not match, refuses to execute the bundle,
and `/admin/` renders blank. There is no console-free way to notice.

So bumping is two edits, not one:

```bash
VERSION=0.192.0
curl -sL "https://unpkg.com/@sveltia/cms@${VERSION}/dist/sveltia-cms.js" \
  | openssl dgst -sha384 -binary | openssl base64 -A
```

Paste that digest after `sha384-` and change the version in the URL to match.

This is deliberately not automated. A Renovate `customManagers` regex can match
the version in the URL, but Renovate has no way to derive an SRI digest, so it
would open a green-looking PR that bricks the page on merge. One line bumped a
few times a year is not worth that failure mode.

Pin an exact version rather than a range. An unpinned CDN URL means the editor
can change under you between one save and the next, and a regression in a CMS
that writes to your repo is worth catching in a PR instead of live.

After any bump, open `/admin/`, load an existing post, save it, and check the
diff is empty. That catches serialization changes, which are the ones that
damage content.

## Local development

```bash
make serve
```

Then open <http://localhost:1313/admin/index.html> and choose **Work with Local
Repository**. This uses the File System Access API to edit files in the working
tree directly — no auth, no commits, no network round-trip. Changes show up as
ordinary unstaged edits for you to review and commit.

Chromium-based browsers only (Chrome, Edge, Brave). Firefox and Safari have not
shipped the API, and the button will not appear there.

This is the right way to try config changes. Editing `config.yml` and reloading
`/admin/` gives you the new form immediately.

## Rollback

Nothing else in the site depends on the CMS, so removing it is four reverts:

```bash
rm -rf static/admin/
```

Then drop `Disallow: /admin/` from `layouts/robots.txt` and remove the Sveltia
paragraph from `CLAUDE.md`.

`scripts/check-cms-fields.sh` and its test can stay or go. The guard is only
meaningful while the CMS exists, but it is harmless without it — with no
`config.yml` present the script exits 1 with a "config not found" error, so if
you keep it, also drop both lines from the `test:` target in the `Makefile`.

Content is untouched by any of this. The CMS never stored anything of its own.
