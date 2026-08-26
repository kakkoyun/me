---
title: "talk: Prometheus Updates and Deep Dive"
description: "The Prometheus maintainer track session at KubeCon EU 2023: how the pieces fit together, what had recently shipped, and where the project was heading."
date: 2023-04-19T00:00:00Z
publishDate: 2023-04-19T00:00:00Z
categories:
  - talks
tags:
  - talks
  - prometheus
  - observability
  - monitoring
  - cloud-native
  - kubernetes
cover:
  image: https://img.youtube.com/vi/qQpehBEOakY/maxresdefault.jpg
  alt: Prometheus Updates and Deep Dive
  caption: KubeCon + CloudNativeCon Europe 2023
---

Prometheus is the second-oldest project in the CNCF and the default answer for metrics in Kubernetes. Which means most people meet it already running, configured by someone who has since left, and never get a chance to ask how the thing works.

This is the maintainer track session for people in that position. We start from the beginning for anyone who has only ever touched Prometheus through a Grafana panel: what it scrapes, what it keeps, and what the query engine is actually doing while your dashboard spins. Then we go under the covers into the storage layer, the write path, and the places the memory tends to go.

The rest is the changelog nobody reads. Bryan and I go through the features that had landed recently, the ones that were still in flight, and the parts of the project where a new contributor could usefully start.

Co-presented with [Bryan Boreham](https://github.com/bboreham) of Grafana Labs.

One caveat worth stating plainly: this was recorded in April 2023. The architecture holds up, but treat anything described as "coming soon" as history rather than a roadmap.

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/qQpehBEOakY" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Links**

* [Prometheus](https://github.com/prometheus/prometheus)

**Events**

* [KubeCon + CloudNativeCon Europe 2023](https://kccnceu2023.sched.com/event/1HzcT) — Amsterdam, maintainer track
  * [Recording](https://www.youtube.com/watch?v=qQpehBEOakY)
