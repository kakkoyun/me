# Social Media Promotion

Two paths can promote a post to social media. Only one is active at a time.
Both read the same frontmatter, so a post opts in or out of both with one flag.

| Path | State | How it runs |
| --- | --- | --- |
| External feed consumer | **Active** | An external system reads `/feed.xml` and posts on its own schedule |
| Claude + Buffer workflow | **Paused** | `.github/workflows/promote-post.yml`, manual `workflow_dispatch` only |

## The flag

`promote` defaults to true. Set `promote: false` in frontmatter to opt a post
out of both paths.

```yaml
promote: false
```

The `promotedAt` ledger only concerns the Claude + Buffer path. The external
consumer never reads or writes it.

## The feed: /feed.xml

`layouts/index.feed.xml` emits a full-text RSS feed, configured as the `feed`
output format in `config.yaml` and served at `/feed.xml`.

What the feed contains:

- Blog posts only (`content/posts`). Talks and notes are not promoted.
- Every post with `promote` not false. This matches how
  `scripts/find-promotable-posts.sh` reads the same flag.
- No drafts and no future-dated posts. The production build omits them.
- Full-text `<content:encoded>` with the same body treatment as
  `/substack.xml`: absolutised image and link URLs, flattened code blocks,
  folded sidenotes and tooltips, cover image prepended.
- Cross-posts (`canonicalUrl` pointing at a third party) are included. The
  Claude + Buffer path promotes them too, so the feed must not disagree.

What the feed deliberately does not do:

- It has no `promotedAt` logic and no date window. The feed is stateless.
  The consumer tracks which items it already posted.
- It does not check that the post page is live. Publishing is owned by
  `deploy-scheduled.yml` (00:10 UTC), so a merged post is normally live
  before the feed ever shows it. If the consumer posts soon after a merge,
  it should tolerate a not-yet-live link.

### Pointing the external system at the feed

Use the absolute URL `https://kakkoyun.me/feed.xml`. Configure the consumer to
treat each new feed item as one post-worthy post. Deduplication is the
consumer's job: the feed lists every eligible post, newest first, and never
removes an item.

## The Claude + Buffer path (paused)

`promote-post.yml` still works end to end. It is only not triggered
automatically: the nightly `schedule` block is commented out in the `on:`
section, and `workflow_dispatch` stays live.

Run it manually from GitHub Actions ("Promote New Post" → "Run workflow"):

- Leave `post_path` blank to promote everything due and unpromoted, inside the
  30-day lookback window.
- Give a `post_path` to promote one specific post. This ignores both the
  window and the ledger. It is the deliberate re-promote button.
- `dry_run` installs a stub `buffer-cli` that logs instead of posting.

The manual run behaves exactly as the cron did: it finds candidates with
`scripts/find-promotable-posts.sh`, verifies each post is live with
`scripts/check-post-live.sh`, has Claude draft the messages (`kemal-voice` +
`humanizer` skills), posts through Buffer, then stamps `promotedAt` and lands
the stamp on `master` through a PR. The window-plus-ledger mechanism, the
liveness guard, and the known limits of that path are documented in
`CLAUDE.md` and in the workflow file itself.

Local: `/project:promote-post content/posts/<slug>.md` in any Claude Code
session.

### Re-enabling the nightly cron

Uncomment the `schedule` block in the `on:` section of
`.github/workflows/promote-post.yml`.

Before you do, decide which path owns promotion:

1. Stop the external consumer first, or confirm the two paths will not post
   the same links.
2. The ledger records only what this workflow posted. The first re-enabled
   run sees every post inside the lookback window as unpromoted, including
   posts the external consumer already published. Stamp `promotedAt` on those
   posts by hand before the first cron fires, or accept the re-posts.

## History

The cron ran nightly at 6 AM UTC. It was disabled in favor of the external
feed consumer in February 2026. The workflow file keeps the full record of
why the schedule was fragile and how the stamp lands through a PR.
