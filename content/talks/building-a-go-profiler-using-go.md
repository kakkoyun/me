---
title: "talk: Building a Go Profiler Using Go"
description: "Learn how to build a Go profiler using eBPF technology, combining portable eBPF programs with Go for continuous profiling and performance analysis in cloud-native environments."
date: "2022-03-20T00:00:00Z"
publishDate: "2022-03-20T00:00:00Z"
categories:
  - talks
tags:
  - talks
  - go
  - profiling
  - eBPF
cover:
  image: https://img.youtube.com/vi/OlHQ6gkwqyA/hqdefault.jpg
  alt: Building a Go Profiler Using Go
  caption: Building a Go Profiler Using Go
---

Profiling has long been part of the Go developer’s toolbox to analyze the resource usage of a running process. But do you ever wonder how profilers built? In this talk, I will bring eBPF (a promising Kernel technology) and Go together to build a profiler for understanding Go code at runtime.

Profiling has long been part of the developer’s toolbox to analyze the resource usage of a running process. Go users are very familiar with the concept thanks to state-of-art Go tooling. For years Google has consistently been able to cut down multiple percentage points in their fleet-wide resource usage every quarter, using techniques described in their “Google-Wide Profiling” paper, which is called continuous profiling. Through continuous profiling, the systematic collection of profiles, entirely new workflows suddenly become possible.

In parallel, eBPF became a new promising technology, is likely not news to most people in cloud space. We are discovering more use cases where eBPF can be useful, especially when combined with Go and modern infrastructure, from security, over observability to performance tuning. For a long time, eBPF has struggled with portability, it needed to be compiled for each kernel, or a compiler and kernel headers needed to be shipped to execute effectively arbitrary code. The eBPF community acknowledged this and started the CO:RE (compile once-run everywhere) initiative, which is young but quickly maturing in the form of libbpf and libbpf-go.

In this talk, we will bring these two concepts together, and explain how to write portable eBPF programs and embed them in Go applications. And what libbpf-go does in order to achieve compile once-run everywhere, how it can be used in portable Go applications. We will demonstrate all concepts together by using real-life examples to help measure and improve performance systematically.

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/OlHQ6gkwqyA" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

#### [Demo Application](https://github.com/kakkoyun/tiny-profiler)

**Slides**

* [Building a Go Profiler Using Go](https://docs.google.com/presentation/d/1hKqxAC9aaWLPM4xwXyXuK5cp2LBAewOVqZ05qjLNnK8/edit?usp=sharing)

**Events**

* [GopherCon EU 2022](https://gophercon.eu)
  * [Recording](#building-a-go-profiler-using-go)
