# me

[![Netlify Status](https://api.netlify.com/api/v1/badges/823ca2f7-48b6-4cb1-ae9c-e9340ac7d7d3/deploy-status)](https://app.netlify.com/sites/kakkoyun/deploys)
[![Hugo PaperMod](https://img.shields.io/badge/theme-hugo--PaperMod-3eaf7c)](https://github.com/adityatelange/hugo-PaperMod)

Source for [kakkoyun.me](https://kakkoyun.me) personal website including blog posts.

## Quick Start

Clone the repo and run the one-shot setup (wraps `check-hugo` for auto-install + theme init):

```shell
make local-setup
```

Then start the dev server:

```shell
make serve
```

Or include drafts & future-dated content:

```shell
make serve-draft
```

### Manual (alternative) setup

If you prefer manual steps:

```shell
git submodule update --init --recursive
```

Update the theme later with:

```shell
git submodule update --remote --merge
```

## What does it include?

* Overview page
* Blogposts
* Archive page
* Search functionality
* Multilingual support
* Light/Dark mode
* Netlify deployment

## Makefile Commands

This project includes a Makefile for common Hugo operations:

```shell
# Build the site
make build

# Run local development server
make serve

# Run server with drafts
make serve-draft

# Deploy to Netlify
make netlify-deploy
```

Run `make help` to see all available commands.

## Troubleshooting Local Preview

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Blank site / theme templates missing | Theme submodule not initialized | `make local-setup` or `git submodule update --init --recursive` |
| Broken styles / missing CSS | Using non-extended Hugo build | Install extended binary matching `.hugo-version` (see `make check-hugo` output) |
| Base URL links point to production domain when testing | `baseurl` + `canonifyUrls: true` in `config.yaml` | Run with a local override: `hugo server -D --baseURL http://localhost:1313 --canonifyURLs=false` if needed |
| 404s for newly added content | Draft or future-dated content | Use `make serve-draft` |
| Version mismatch warning | Installed Hugo != `.hugo-version` | Reinstall correct version or run `make update-version` |

### Verifying Hugo & Theme

Check Hugo version & theme presence:

```shell
hugo version
test -f themes/PaperMod/theme.toml && echo THEME_OK || echo THEME_MISSING
```

### Clean Rebuild

Sometimes caches cause confusion:

```shell
make clean && make serve
```

## Updating Hugo Version

```shell
make update-version
```

This updates `.hugo-version` and synchronizes `netlify.toml`.

## What open source tools I have used to build this?

* [Hugo](https://gohugo.io/overview/introduction/)
* Theme [Hugo PaperMod](https://github.com/adityatelange/hugo-PaperMod)
* [Netlify](https://netlify.com/) for hosting and deployment

## Can I copy the code for my own website?

Of course, all except blog content is licensed with Apache 2 license.

## Documentation

For detailed information about the PaperMod theme configuration and features, see the [documentation](documentation.md) file.

## License and Copyright

This project is licensed under the [Apache License 2.0](LICENSE).
