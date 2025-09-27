---
categories:
  - talks
tags:
  - talks
  - go
  - observability
  - cloud-native
date: "2020-12-01T00:00:00Z"
publishDate: "2020-12-01T00:00:00Z"
title: "talk: Building Observable Go Services"
cover:
  image: https://img.youtube.com/vi/xkLyM1Gnaus/maxresdefault.jpg
  alt: Building Observable Go Services
  caption: Building Observable Go Services
---

In modern days, we run our applications as loosely coupled micro-services on distributed, elastic infrastructure as (mostly) stateless workloads. Under these circumstances, observability has become a key attribute to understand how our applications run and behave in action, in order to provide highly available and resilient service.

There exist several observability signals, such as “log”, “metric”, “tracing” and “profiling” that can be collected from a running service, which we can also call pillars of observability. Using these signals, we can create real-time, actionable alerts, create panels where we can monitor applications closely, and perform in-depth analysis to find the root of the systems’ failures. Within the Go and CNCF ecosystem, there are a variety of tools that can collect and make these observable signals useful.

During this talk, Kemal will first introduce the tools that can be embedded in the services to make critical services observable, and share the patterns that will enable them to be used efficiently in the applications and services. Moreover,  he will demonstrate how to use these collected signals in real-life scenarios, using tools within the CNCF ecosystem (Loki, Prometheus, OpenTelemetry, Jaeger, Conprof). He also aims to share the methods that are used to build and run applications running under heavy-traffic, and to understand the origin of the problems encountered in running systems.

#### [Recording](https://www.youtube.com/watch?v=xkLyM1Gnaus)

**Slides**

* [Building Observable Go Services](https://github.com/kakkoyun/building-observable-go-services)

**Events**

* [GopherCon Turkey 2020](https://gophercon.ist/en)
  * [Recording](https://www.youtube.com/watch?v=xkLyM1Gnaus)
