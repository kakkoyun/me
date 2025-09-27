---
categories:
  - talks
tags:
  - talks
  - observability
  - instrumentation
  - cloud-native
  - Prometheus
date: "2022-11-08T00:00:00Z"
publishDate: "2022-11-08T00:00:00Z"
title: "talk: Best Practices and Pitfalls of Instrumenting Your Cloud-Native Application"
cover:
  image: https://img.youtube.com/vi/B6Ds2myOIRc/maxresdefault.jpg
  alt: Best Practices and Pitfalls of Instrumenting Your Cloud-Native Application
  caption: Best Practices and Pitfalls of Instrumenting Your Cloud-Native Application
---

Observability is crucial for understanding how your application operates in real-time. Among various observability signals—such as logs, traces, and continuous profiling—metrics play a significant role. They provide sampled measurements throughout the system, essential for ensuring service quality, improving performance, scalability, debuggability, security, and enabling real-time, actionable alerting.

Building observable applications begins with proper instrumentation. While the Prometheus ecosystem offers tools that simplify this process, there are still numerous opportunities for mistakes or misuse.

In this talk, Jéssica Lins and Kemal Akkoyun present several useful patterns, best practices, and idiomatic methods for instrumenting critical services. They discuss common pitfalls, failure cases, and instrumentation strategies, sharing valuable insights and methods to avoid these mistakes. Additionally, they provide tips for writing simple, maintainable, and robust instrumentation facilities using real-life examples. The talk also demonstrates how to enrich metrics by correlating them with other observability signals and discusses how to best utilize recent changes in `client_golang`, the Go client library for Prometheus.

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/B6Ds2myOIRc" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Slides**

* [Best Practices and Pitfalls of Instrumenting Your Cloud-Native Application](https://docs.google.com/presentation/d/1uRyWxPGTTfn9_UnX4sWyUd5Lcf7MKg-qvi3hajFtLZI/edit?usp=sharing)

**Events**

* [PromCon EU 2022](https://promcon.io/2022-munich/talks/best-practices-and-pitfalls-of-i/)
  * [Recording](https://www.youtube.com/watch?v=B6Ds2myOIRc)
