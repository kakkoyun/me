# me

[![Netlify Status](https://api.netlify.com/api/v1/badges/823ca2f7-48b6-4cb1-ae9c-e9340ac7d7d3/deploy-status)](https://app.netlify.com/sites/kakkoyun/deploys)
[![Hugo PaperMod](https://img.shields.io/badge/theme-hugo--PaperMod-3eaf7c)](https://github.com/adityatelange/hugo-PaperMod)

Source for [kakkoyun.me](https://kakkoyun.me) personal website including blog posts.

Once cloned, make sure to run:

```shell
git submodule update --init --recursive
```

To update the theme:

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
