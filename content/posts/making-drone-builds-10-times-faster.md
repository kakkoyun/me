---
canonicalUrl: https://underthehood.meltwater.com/blog/2019/04/10/making-drone-builds-10-times-faster/
tags:
  - infrastructure
  - berlin
  - CI/CD
  - drone
  - drone.io
  - open-source
date: "2020-04-10T00:00:00Z"
image: https://raw.githubusercontent.com/meltwater/drone-cache/master/images/drone_gopher.png
publishDate: "2020-04-10T00:00:00Z"
title: Making Drone Builds 10 Times Faster!
---

We open sourced [drone-cache][drone-cache], a plugin for the popular Continuous Delivery platform [Drone][drone]. It allows you to cache dependencies and interim files between builds to reduce your build times. This post explains why we are using Drone, why we needed a cache plugin, and what I learned while trying to release drone-cache as open source software.

Read on for the story behind drone-cache or if you want to jump into action directly, go to the [github.com/meltwater/drone-cache][drone-cache], and try it for yourself.

_Originally published at_ [_underthehood.meltwater.com_](https://underthehood.meltwater.com/blog/2019/04/10/making-drone-builds-10-times-faster/) _on April 10, 2019._

![Drone Cache Logo](https://raw.githubusercontent.com/meltwater/drone-cache/master/images/drone_gopher.png)

## Why are we using Drone?

At Meltwater, we empower self-sufficient teams. Teams are free to choose their technology stacks. As a result, we have a diverse set of tools in our stack. In my team, we had been using a combination of [TravisCI][travisci], [CircleCI][circleci] and [Jenkins][jenkins] as our [CI/CD pipeline][ci/cd-pipeline].

In 2018, we decided to migrate to [Kubernetes][kubernetes]. In doing so, we wanted to simplify our toolchain and migrate to a more flexible, [cloud-native][cloud-native] and on-premise CI/CD pipeline solution. We ended up choosing [Drone][drone], and with one year of experience under our belt, we are more than happy with it.

## How we made the builds faster

My team lives and breaths the "[release early, release often][release-early,-release-often]" philosophy. We release and deploy our software to production several times a day. When we moved from CircleCI to Drone, our build times went up drastically.

Build times went up so much because, for each build, our package manager was downloading the Internet (you know, usual suspects are [npm][npm], [RubyGems][rubygems], etc.). This was not a problem with CircleCI because of their built-in caching facilities. So with our pace of continuous releases and increased build times, we got frustrated quickly.

![How does it work?](https://raw.githubusercontent.com/meltwater/drone-cache/master/images/diagram.png)

Since we had been spoiled with the wonderful caching features of CircleCI, we wanted the same features in Drone but they are not available by default. However, Drone offers [plugins][plugins] which are "special Docker containers used to drop preconfigured tasks into a Pipeline". We found tens of plugins related to caching in Drone.

We first tried [drone-volume-cache][drone-volume-cache], but because volumes are local to the currently running Drone worker node, you cannot be sure your that next build will run on the same machine. Using a storage layer that could persist the cache between builds would be a better option. So we quickly abandoned this approach.

Our Drone deployment runs on [AWS][aws], hence we looked for plugins that use [S3][s3] as their storage. We found lots of them and decided to use [drone-s3-cache][drone-s3-cache]. It’s a well-written, simple Go program which follows the Drone [plugin starter][plugin-starter] conventions.

## Why did we decide to build our own caching plugin?

After using _drone-s3-cache_ for a couple of weeks, we needed to add another parameter to pass to S3. To do so we forked [drone-s3-cache][drone-s3-cache] and modified it. We thought that nobody would need those minor changes. So rather than contributing back to upstream, we built a docker image of our own and pushed it to our private registry to use as a custom Drone plugin.

![Feature request for drone-cache from a colleague](https://raw.githubusercontent.com/meltwater/drone-cache/master/images/slack_comment.png)

Months later, I have received a feature request from one of my colleagues working in a different team, and I was surprised because I didn’t think other teams used drone-cache. When I checked, I realised that various teams throughout Meltwater heavily used it. Then we started to get similar messages and requests from other teams.

I received this message when I was looking for a problem to solve during our [internal][internal] [Hackathon][hackathon]. What are the chances? So I decided to work on this plugin and add the requested feature. Building something to make life easy for fellow developers always gives me pure joy. Long story short, stars were aligned, and we decided to work on our fork and improve it.

I had not worked with Go much, but I always wanted to learn. Thanks to this plugin, I have also achieved this goal of mine. I changed, refactored and churned a lot of code. I experimented with a lot of different ideas. I have added features that nobody has asked for. I tried different things just for the sake of trying. That’s why when I decided to open source my changes, I realised I had re-written the plugin. So rather than sending a pull-request, I created a new repository. [drone-cache][drone-cache] has born!

![Standards](https://imgs.xkcd.com/comics/standards.png)

## How does it work?

What does a Drone cache plugin actually have to accomplish? In Drone, each step in the build pipeline is a container which is thrown away after it serves its purpose. So a caching system has to persist current workspace files between builds. You can think of [workspace][workspace] as the root of your git repository. It is a mounted volume shared by all steps in your Drone build pipeline.

With drone-cache, after your initial pipeline run, a snapshot of your current workspace will be stored. Then you can restore that snapshot in your next build, which saves you time.

The best example would be to use this plugin with your package managers such as [npm][npm], [Mix][mix], [Bundler][bundler] or [Maven][maven]. With restored dependencies from a cache, commands such as _npm install_ would only need to download new dependencies, rather than re-download every package on each build.

## What makes drone-cache different from other Drone caching solutions?

The most useful feature of drone-cache is that you can provide [your own custom cache key templates][your-own-custom-cache-key-templates]. This means you can store your cached files under keys which prescribes your use cases. For example, with a custom key generated from a checksum of a file (say _package.json_), you keep your cached files until you actually touch that file again.

All other caching solutions for drone offer only a single storage form for your cache. drone-cache in contrast offers 2 storage forms out of the box: an **S3 bucket** or a **mounted volume**. Even better, drone-cache provides a pluggable backend system, so you can implement your own storage backend.

Last but not least, drone-cache is a small CLI program, written in Go without any external OS dependencies. So even if you are not using Drone as your build system, you can still fork and tinker with drone-cache to make it fit your needs.

## What we have learned?

Building a caching solution is hard. Especially, if every team in your company uses it every time they push something to their repositories. It is also fun because it means you have users who give you feedback from the beginning. With the help of my colleagues' feedback and feature requests, we have crafted this plugin.

> There are only two hard things in Computer Science: cache invalidation and naming things.
> -- Phil Karlton

What could we have done better? As I have mentioned before, rather than forking and modifying a new code base, we could have contributed back to the original project. We could have applied "release early and often" philosophy to open sourcing this repository, and we would have collected feedback from the outside world as well. However we didn’t, that’s mostly on me. This is the first time I actually open sourced a project and contributed back to the community. So next time I will know better :)

In Meltwater we are using _drone-cache_ in 20 teams and 120 components now. It works and gets things done for us. We have learned a lot while we build it. We hope this also solves similar problems of yours.

Please [try it][drone-cache] in your pipeline, give us feedback, feel free to open issues and send us pull-requests. Personally, I am also very interested to discuss your experiences with open sourcing in general, so if you have any thoughts on that, please share them in the comments below.

**Image Credits**

xkcd.com - How standards proliferate [https://xkcd.com/927/][https://xkcd.com/927/]

_Originally published at_ [_underthehood.meltwater.com_](https://underthehood.meltwater.com/blog/2019/04/10/making-drone-builds-10-times-faster/) _on April 10, 2019._

[drone-cache]: https://github.com/meltwater/drone-cache
[drone]: https://drone.io/
[travisci]: https://travis-ci.com/
[circleci]: https://circleci.com/
[jenkins]: https://jenkins.io/
[ci/cd-pipeline]: https://en.wikipedia.org/wiki/CI/CD
[kubernetes]: https://kubernetes.io/
[cloud-native]: https://github.com/cncf/toc/blob/master/DEFINITION.md
[release-early,-release-often]: https://en.wikipedia.org/wiki/Release_early,_release_often
[npm]: https://www.npmjs.com/
[rubygems]: https://rubygems.org/
[plugins]: http://plugins.drone.io/
[drone-volume-cache]: https://github.com/Drillster/drone-volume-cache
[aws]: https://aws.amazon.com/
[s3]: https://aws.amazon.com/s3/
[drone-s3-cache]: https://github.com/bsm/drone-s3-cache
[plugin-starter]: https://github.com/drone/drone-plugin-starter
[internal]: https://underthehood.meltwater.com/blog/2014/08/18/meltwhatever-innovation-day-at-meltwater/
[hackathon]: https://en.wikipedia.org/wiki/Hackathon
[workspace]: https://docs.drone.io/user-guide/pipeline/steps
[mix]: https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html
[bundler]: https://bundler.io/
[maven]: https://maven.apache.org/
[your-own-custom-cache-key-templates]: https://github.com/meltwater/drone-cache/blob/master/docs/cache_key_templates.md
[https://xkcd.com/927/]: https://xkcd.com/927/
