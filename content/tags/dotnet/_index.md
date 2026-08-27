---
# The tag is stored as `dotnet`, not `.Net`, on purpose: Hugo urlizes `.Net` to
# `/tags/.net/`, and Netlify drops every dot-prefixed directory from the publish
# directory (only `.well-known` is exempt). That page was in sitemap.xml and
# linked from the post, but served a 404 — Search Console reported it as such.
# This term page keeps the label `.Net` while the URL stays `/tags/dotnet/`;
# `static/_redirects` 301s the old path, and `scripts/verify-build.sh` fails the
# build if a dot-prefixed directory reappears under public/.
title: ".Net"
linkTitle: ".Net"
---
