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

1. **GitHub App** (github.com → Settings → Developer settings → GitHub Apps),
   registered for this repo alone. Holds the client ID and secret. Its user
   authorization callback URL points at Netlify's OAuth gateway, not at this
   site.
2. **Netlify OAuth provider** (Netlify → Site settings → Access control →
   OAuth). The GitHub client ID and secret are pasted here. Netlify runs the
   token exchange so the secret never reaches the browser.
3. **`backend:` in `config.yml`.** Names the repo and branch. No `base_url` —
   Netlify's gateway is the default for sites hosted on Netlify, so pointing at
   it explicitly would be redundant.

A GitHub App rather than a classic OAuth App, deliberately. Both use the same
`/login/oauth/authorize` endpoints, so Netlify's gateway does not know the
difference — but the token each one mints is very different. An OAuth App issues
a `repo`-scoped token covering *everything* the signer can reach, including
their employer's private repositories. A GitHub App issues a user-to-server
token carrying only:

```
app permissions  ∩  the signer's own permissions  ∩  where the app is installed
```

### Who can get in

Anyone on the internet can load `/admin/` and start the sign-in flow. That is
fine, and it is worth understanding exactly why.

The app is installed on `kakkoyun/me` and nowhere else, and it asks for
`Contents: read and write` plus `Metadata: read-only`. Intersect that with a
stranger's permissions on this repo — none — and their token can read and write
nothing. They land on an editor that cannot load a single file. There is no
allowlist inside Sveltia doing this work; **the repo's push list is the
allowlist**, which is why `scripts/check-repo-access.sh` asserts that list is
exactly one account (see below).

### GitHub App settings that carry weight

Re-walk these roughly yearly. They are console state, not repository state, so
nothing in CI can check them — adding the App's private key as a secret to
automate it would trade a real credential for a small convenience.

| Setting | Value | Why |
| --- | --- | --- |
| Where can this app be installed? | **Only on this account** | Nobody else can install it anywhere |
| Permissions | `Contents: RW` + `Metadata: R` | Sveltia commits files. `cms-pr.yml` opens the PR with `CMS_PR_TOKEN`, so `Pull requests` is not needed here |
| User authorization callback URL | `https://api.netlify.com/auth/done`, and only that | A second callback URL is a token-redirect hole |
| Expire user authorization tokens | **On** | Netlify's gateway hands back no refresh token, so this means re-signing-in each session. That is the price of an 8-hour blast radius instead of an indefinite one |
| Enable Device Flow | Off | Nothing here uses it |
| Webhook | Off | Nothing consumes it |
| Installed on | `kakkoyun/me` only | Not "All repositories" |

### What the CMS token can and cannot do

`Contents: read and write` is not branch-scoped: a stolen token could push
straight to `master` and publish to the live site, sailing past the `cms` → PR
review gate below. A ruleset on `master` closes that, and the shape of it
matters:

- require a pull request, **0 required approvals** — you are the only
  collaborator and cannot approve your own PR, so the gate is the PR plus its
  checks, not a second human. This also keeps `merge-schedule.yml` able to merge.
- required status checks: `build` and `links`.
- bypass actors: **the `GitHub Actions` app only** — not "repository admin".

That last line is the whole point. `.github/workflows/main.yml` pushes
`content/notes/_index.md` to master on a daily cron using `GITHUB_TOKEN`, so it
needs the bypass. A CMS session's token is a *user* token, so it does not get
one. The cost: an emergency revert also goes through a PR — with 0 approvals
that is just the check time, but it is not instant.

### Security headers on `/admin/`

After sign-in the token lives in the browser's **localStorage** on the
`kakkoyun.me` origin. `netlify.toml` therefore serves a Content-Security-Policy
on `/admin/*` (plus a site-wide baseline of `X-Content-Type-Options`,
`Referrer-Policy`, `X-Frame-Options` and `Permissions-Policy` on `/*`).

`connect-src` is the load-bearing directive: it names the handful of hosts the
editor may talk to, so an injected script cannot POST the token anywhere else.
`script-src` pins the two inline blocks in `static/admin/index.html` by sha256.

Two things about that policy are easy to get wrong:

- **Do not add `Cross-Origin-Opener-Policy`.** Sign-in is a popup that
  `postMessage`s the token back to `window.opener`; `COOP: same-origin` severs
  that reference and breaks login. Both check scripts assert its absence.
- **Self-hosting the bundle would not drop the CDN.** The `sha384` integrity
  attribute covers the top-level file, but the bundle lazily `import()`s
  `@shikijs/*`, `@sveltia/ui`, `emojilib` and pdf.js from hardcoded
  `https://unpkg.com` URLs at runtime, and pulls webfonts from
  `cdn.jsdelivr.net`. Those chunks have no SRI, which is exactly why the
  `connect-src` allowlist matters.

**Honest residual:** localStorage is per-origin, not per-path. A CSP on
`/admin/*` does not stop XSS on a *blog* page from reading the token, and the
blog loads third-party JS (plausible.io, tracker.hakanai.io, giscus.app). The
8-hour token expiry and the `master` ruleset are what bound that. The complete
fix is moving `/admin` to its own origin; that is a deliberate non-goal for now.

There is no site-wide CSP. PaperMod, the Giscus theme sync and the JSON-LD
partial all emit inline `<script>` blocks, so one would need `'unsafe-inline'`
and would be decorative. `check-live-headers.sh` fails if a CSP ever appears on
`/` so that nobody adds a decorative one by accident.

### What CI checks

| Script | Runs | Asserts |
| --- | --- | --- |
| `scripts/check-admin-csp.sh` | `make test` → `lint.yml`, every PR | the CSP in `netlify.toml` still matches `static/admin/index.html` — inline-script hashes, bundle origin and pinning, a non-wildcard `connect-src`, no COOP |
| `scripts/check-live-headers.sh` | `links.yml`, master pushes + weekly | the deployed site actually *serves* those headers. Nothing appears in the build output for a header rule, so this is the only place a silently-dropped header would surface |
| `scripts/check-repo-access.sh` | `links.yml`, master pushes + weekly — **only if `REPO_ADMIN_TOKEN` is set** | push access to this repo is exactly `kakkoyun` |

Run any of them by hand:

```bash
bash scripts/check-admin-csp.sh
BASE_URL="$DEPLOY_PRIME_URL" bash scripts/check-live-headers.sh
GITHUB_TOKEN=... bash scripts/check-repo-access.sh
```

`check-live-headers.sh` and `check-repo-access.sh` need the network, so they are
not part of `make test`; only their offline unit tests are.

**`check-repo-access.sh` cannot run on a workflow `GITHUB_TOKEN`.** The
collaborators endpoint needs `Administration: read`, and `administration` is not
a settable key in a workflow `permissions:` block — so a workflow token always
gets a 403 there. Rather than add a long-lived PAT to this repo purely to run a
tripwire, the CI step is gated on an optional `REPO_ADMIN_TOKEN` secret and
skips with a `::notice::` when it is absent. Two ways to get the check anyway:

- **By hand**, whenever you touch collaborators, and during the yearly audit:
  `GITHUB_TOKEN=$(gh auth token) bash scripts/check-repo-access.sh`
- **Continuously**, if you decide it is worth a credential: create a
  fine-grained PAT scoped to `kakkoyun/me` with `Administration: read` and
  nothing else, give it an expiry, and store it as `REPO_ADMIN_TOKEN`. It is
  read-only and single-repo, so a leak exposes repository settings and nothing
  else — but it is still a credential to rotate, which is why it is opt-in.

On a personal repo this is a tripwire for your own forgetfulness rather than a
defence against someone else granting access, since only you can add a
collaborator. That is what makes the manual option reasonable.

Editing `static/admin/index.html` changes an inline script's hash, so
`make test` will fail until the new hash is in `netlify.toml`. Recompute with:

```bash
perl -0777 -ne 'while (/<script>(.*?)<\/script>/gs) {
  open(my $p, "|-", "openssl dgst -sha256 -binary | openssl base64 -A"); print $p $1; close $p; print "\n" }' \
  static/admin/index.html
```

### Turning the CSP on

It ships as `Content-Security-Policy-Report-Only` first. Report-Only never
blocks anything, so landing it cannot break the editor — it only reports.

Because `/admin/` has exactly one user, your own devtools console *is* the
complete violation report; there is no population of other users whose breakage
you would miss. Soak it over real editing sessions with the console open, and
deliberately exercise the paths that pull the lazy chunks: the media library, a
post with a fenced code block (Shiki), the emoji picker, a sidenote or tooltip
component, and a save that lands a commit on `cms`. Fold any real violations
into the policy.

To flip it, change the header name in `netlify.toml` to
`Content-Security-Policy` and set `EXPECT_CSP_ENFORCED: '1'` on the
`security-headers` job in `links.yml`. Keep it a one-line-each diff, in its own
PR: rollback is then a `git revert` plus a redeploy, roughly two minutes, with
no archaeology under pressure.

Commits made through the CMS use the `commit_messages` templates in
`config.yml`, so they land as `post: create <slug>` and match the repo's commit
style. The prefix is `{{collection}}`, which Sveltia renders as the collection's
`label_singular` — that is why those are lowercase in the config. A talk commits
as `talk: update <slug>`, a newsletter issue as `newsletter: update <slug>`.

### Rotating credentials

Two long-lived credentials back the CMS. Rotate both on a leak, and on a routine
schedule.

**The GitHub App client secret** — used by Netlify to exchange auth codes:

1. GitHub → the GitHub App → **Generate a new client secret**.
2. Netlify → Site settings → Access control → OAuth → paste the new secret.
3. Delete the old secret on GitHub.

No code change and no deploy. The client ID stays the same unless you replace
the whole app. Existing editor sessions keep working until their token expires.

**`CMS_PR_TOKEN`** — the fine-grained PAT `cms-pr.yml` uses to open the review
PR (Contents: read, Pull requests: write). Give it an expiry rather than "no
expiration", and diary the rotation:

1. GitHub → Settings → Developer settings → Fine-grained tokens → regenerate.
2. Repo → Settings → Secrets and variables → Actions → update `CMS_PR_TOKEN`.
3. Push a trivial commit to `cms` and confirm the review PR still opens.

If it lapses, `cms-pr.yml` fails and no review PR appears — saves still land on
`cms`, but nothing surfaces them.

**Revoking a session.** github.com/settings/applications → the app → revoke.
That kills the browser's token immediately; the next `/admin/` load asks for
sign-in again. Do this if you sign in on a machine you do not control.

## Review gate

Saves do not go to master. The CMS commits to a long-lived `cms` branch, and CI
opens one pull request from it:

```
save in /admin/  →  commit on `cms`  →  PR opens (or the existing one grows)
                 →  build + prose + links + Netlify deploy preview
                 →  review, merge  →  live  →  `cms` fast-forwards to master
```

Two workflows implement it:

| File | Trigger | Does |
| --- | --- | --- |
| `.github/workflows/cms-pr.yml` | push to `cms` | opens the review PR if none is open |
| `.github/workflows/cms-sync.yml` | push to `master` | fast-forwards `cms` to master |

Sveltia has a `publish_mode: editorial_workflow` setting inherited from
Netlify/Decap CMS, but its docs mark it **Unimplemented** — it is inert config
today. The branch-plus-PR arrangement is the substitute.

`netlify.toml` sets `[context.branch-deploy] ignore = "exit 0"`, so a push to
`cms` never produces a branch deploy. It does produce a deploy preview once the
PR is open, and `pull_request` is the trigger for `build.yml`, `prose.yml` and
`links.yml` — all four run again on every later save, because each save pushes a
commit that updates the PR head. Budget for one build per save, not one per
review cycle; the branch-deploy setting only stops that from being two builds
per save. `[context.deploy-preview]` passes `--buildFuture`, so future-dated
posts render in the preview, which is the case you cannot check on production.

### What this costs you

- **All in-flight edits share one PR.** You cannot merge one post while holding
  another back. Set `draft: true` on the one being held.
- **Merge with a merge commit, never a squash.** `cms-sync.yml` fast-forwards
  `cms` to master, which requires `cms` to be an ancestor of master. A squash
  produces a commit that is not descended from the `cms` commits, so the
  fast-forward check fails and the branch is left behind. The job refuses to
  force rather than destroying work, so the failure is loud — but clearing it
  needs a manual `git push --force origin master:cms`.
- **It needs a PAT.** A PR opened with the default `GITHUB_TOKEN` does not
  trigger `pull_request` workflows, so `build.yml`, `prose.yml` and `links.yml`
  would stay silent on the run that matters. Store a fine-grained token
  (Contents: read, Pull requests: write) as the `CMS_PR_TOKEN` repository
  secret. Without it `cms-pr.yml` fails and no review PR appears at all.

### Bringing the branch back by hand

If `cms` drifts — a squash merge, or an aborted edit you do not want — reset it
to master:

```bash
git fetch origin
git push --force origin origin/master:refs/heads/cms
```

Nothing is lost that is not already on master; a CMS save that has not been
merged is a commit on `cms` and would be discarded, so check the open review PR
first.

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
directories and asserts each one is declared on the collection that owns that
directory.

The check is per-collection, matching what Sveltia actually does on save.
`series` being declared on posts does not license a `series` key on a talk — the
talks collection has no such field, so Sveltia would drop it. The directories to
scan are not configured anywhere: they are the `folder:` of every collection in
`config.yml`, which is by definition every directory the CMS can write to.
Section pages (`_index.md`) are skipped, since a folder collection hides them
unless it sets `index_file`, and none do.

```bash
bash scripts/check-cms-fields.sh
```

It also runs as part of `make test`, which `lint.yml` runs on every PR.

A failure looks like this:

```
UNDECLARED: 'newKey' found in content/posts/ but not declared on that collection
in .../static/admin/config.yml

Add the missing key(s) as 'widget: hidden' fields to that collection in
.../static/admin/config.yml to prevent Sveltia CMS from silently dropping them
on save.
```

The fix is always the same: add the key to that collection in `config.yml`. Do
not delete the key from the entry to make the check pass.

Two env vars tune it, mostly for testing:

- `CMS_CONFIG` — path to the config (default `static/admin/config.yml`)
- `CMS_CONTENT_ROOT` — directory the `folder:` paths resolve against (default:
  the repo root)

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
rm -rf static/admin/ .github/workflows/cms-pr.yml .github/workflows/cms-sync.yml
git push origin --delete cms
```

Then drop `Disallow: /admin/` from `layouts/robots.txt`, remove the Sveltia
paragraph from `CLAUDE.md`, and delete the `CMS_PR_TOKEN` secret.

`scripts/check-cms-fields.sh` and its test can stay or go. The guard is only
meaningful while the CMS exists, but it is harmless without it — with no
`config.yml` present the script exits 1 with a "config not found" error, so if
you keep it, also drop both lines from the `test:` target in the `Makefile`.

Content is untouched by any of this. The CMS never stored anything of its own.
