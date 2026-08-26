---
title: "talk: Upstream-First, High Scale Prometheus Ecosystem"
description: "A PromCon keynote on running Prometheus at Red Hat scale and why the fixes went upstream instead of into a fork."
date: 2021-05-03T00:00:00Z
publishDate: 2021-05-03T00:00:00Z
categories:
  - talks
tags:
  - talks
  - prometheus
  - observability
  - monitoring
  - cloud-native
  - open-source
cover:
  image: https://img.youtube.com/vi/r0fRFH_921E/maxresdefault.jpg
  alt: Upstream-First, High Scale Prometheus Ecosystem
  caption: PromCon Online 2021
---

A sponsored keynote, which is a genre that usually means a product pitch. This one is about how Red Hat ran Prometheus across a large fleet, and why the patches we needed went upstream rather than into a fork we would have to carry forever.

Past a certain scale, Prometheus stops being one binary you put on a box. It becomes a set of components you assemble, with Thanos or something like it behind it, and the interesting problems move from "how do I scrape this" to how you keep the whole assembly cheap, queryable, and boring to operate. Same ideas, more moving parts.

Upstream-first is the constraint that shapes the rest. Carrying a patched fork is faster this quarter and more expensive every quarter after it, so the work went into the projects themselves. The talk covers what that looked like in practice, and how the same instinct showed up in the other projects we ran alongside Prometheus.

This is from May 2021 and reflects the Red Hat setup of the time, so read the specifics as a snapshot.

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/r0fRFH_921E" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Links**

* [Prometheus](https://github.com/prometheus/prometheus)
* [Thanos](https://github.com/thanos-io/thanos)

**Events**

* [PromCon Online 2021](https://promcon.io/2021-online/) — co-located with KubeCon + CloudNativeCon Europe 2021
  * [Recording](https://www.youtube.com/watch?v=r0fRFH_921E)
