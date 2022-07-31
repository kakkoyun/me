---
title: Talks
date: 2020-03-01T01:57:45.000+01:00
---

This page lists the recorded talks that I have given so far. Not much but it's a start.

### For a more up-to-date list, check [this YouTube playlist](https://www.youtube.com/playlist?list=PL3P7-fer_ILLtH_ZtQDQhDAEgTo5r9OnB).

https://github.com/kakkoyun/tiny-profiler

## [Building a Go profiler Using Go]([https://docs.google.com/presentation/d/1hKqxAC9aaWLPM4xwXyXuK5cp2LBAewOVqZ05qjLNnK8/edit?usp=sharing](https://docs.google.com/presentation/d/1VNx98laKlhRFfzY9o23N5OHpBBJnuYAmZf5l7Mr-CE0/edit?usp=sharing))

Profiling has long been part of the Go developer’s toolbox to analyze the resource usage of a running process. But do you ever wonder how profilers built? In this talk, I will bring eBPF (a promising Kernel technology) and Go together to build a profiler for understanding Go code at runtime.

Profiling has long been part of the developer’s toolbox to analyze the resource usage of a running process. Go users are very familiar with the concept thanks to state-of-art Go tooling. For years Google has consistently been able to cut down multiple percentage points in their fleet-wide resource usage every quarter, using techniques described in their “Google-Wide Profiling” paper, which is called continuous profiling. Through continuous profiling, the systematic collection of profiles, entirely new workflows suddenly become possible.

In parallel, eBPF became a new promising technology, is likely not news to most people in cloud space. We are discovering more use cases where eBPF can be useful, especially when combined with Go and modern infrastructure, from security, over observability to performance tuning. For a long time, eBPF has struggled with portability, it needed to be compiled for each kernel, or a compiler and kernel headers needed to be shipped to execute effectively arbitrary code. The eBPF community acknowledged this and started the CO:RE (compile once-run everywhere) initiative, which is young but quickly maturing in the form of libbpf and libbpf-go.

In this talk, we will bring these two concepts together, and explain how to write portable eBPF programs and embed them in Go applications. And what libbpf-go does in order to achieve compile once-run everywhere, how it can be used in portable Go applications. We will demonstrate all concepts together by using real-life examples to help measure and improve performance systematically.

**Demo Application**

* [https://github.com/kakkoyun/tiny-profiler](https://github.com/kakkoyun/tiny-profiler)

**Slides**

* [Building a Go profiler Using Go]([https://docs.google.com/presentation/d/1hKqxAC9aaWLPM4xwXyXuK5cp2LBAewOVqZ05qjLNnK8/edit?usp=sharing](https://docs.google.com/presentation/d/1VNx98laKlhRFfzY9o23N5OHpBBJnuYAmZf5l7Mr-CE0/edit?usp=sharing))

**Events**

* [GopherCon EU 2022](https://gophercon.eu)
  * [Recording](#building-a-go-profiler-using-go)


## [eBPF? Safety First!](https://youtu.be/oWHQrlE2-G8)

eBPF being a promising technology is no news. And C is the defacto choice for writing eBPF programs. The act of writing C programs in an error-prone process. Even the eBPF verifier makes life a lot easier; it is still possible to write unsafe programs and make trivial mistakes that elude the compiler but are detected by the verifier in the load time, which are preventable with compile-time checks. It is where Rust comes in. Rust is a language designed for safety. Recently the Rust compiler gained the ability to compile to the eBPF virtual machine, and Rust became an official language for Linux. We discover more and more use cases where eBPF can be helpful. We find more efficient ways to build safe eBPF programs that are parallel to these developments. We will demonstrate how we made applications combined with Rust in the data plane for more safety and Go in the control plane for a higher development pace to target Kubernetes for security, observability and performance tuning.

**Slides**

* [eBPF? Safety First!](https://docs.google.com/presentation/d/1hKqxAC9aaWLPM4xwXyXuK5cp2LBAewOVqZ05qjLNnK8/edit?usp=sharing)

**Events**

* [Cloud-Native eBPF Day EU 2022](https://sched.co/zrPZ)
  * [Recording](https://youtu.be/oWHQrlE2-G8)

## [Story of Correlation: Integrating Thanos Metrics with Observability Signals](https://youtu.be/rWFb01GW0mQ)

The CNCF Incubated Thanos project with the large open-source community continues to push boundaries regarding observability and monitoring using Prometheus-based metrics. Together with the Prometheus community, it improves the metric story for Kubernetes clusters and beyond. Things like improved performance, better scalability, debuggability, security, metrics backfilling and query QoS is only the tip of the iceberg. As we know, observability nowadays comes in many flavours. Bunching them together is not a trivial side, given many shapes and collection points. Aside from metrics, we have logs, traces or even continuous profiling. In this talk, Kemal and Bartek, Thanos maintainers, after a quick overview of Thanos, will explain how Thanos can be integrated with those non-metric observability signals. The audience will learn an example, end-to-end ways to correlate multiple observability backends with Thanos for enhanced observability and monitoring experience.

**Slides**

* [Story of Correlation: Integrating Thanos Metrics with Observability Signals](https://docs.google.com/presentation/d/1FvMqgD5jL5_eoUs6CgIFiBS06U0Ge1CBSXZKz26fsac/edit?usp=sharing)

**Events**

* [KubeCon EU 2022](https://sched.co/ytsK)
  * [Recording](https://youtu.be/rWFb01GW0mQ)

## [Profiling Go Applications in the Cloud-Native Era](https://youtu.be/-miC_jnQ_Yk)

For years Google has consistently been able to cut down multiple percentage points in their fleet-wide resource usage every quarter, using techniques described in their “Google-Wide Profiling” paper. Ad-hoc profiling has long been part of the developer’s toolbox to analyze the CPU and memory usage of a running process. However, through continuous profiling, and the systematic collection of profiles, entirely new workflows suddenly become possible.

The presenter will start this talk with an introduction to profiling applications, and demonstrate how one can practice it using open-source continuous profiling tools, and how continuous profiling allows for an unprecedented fleet-wide understanding of code at production runtime.

Attendees will learn how to continuously profile their code, guide themselves in building robust, reliable, and performant software and reduce cloud spending systematically.

**Slides**

* [Profiling Go Applications in the Cloud-Native Era](https://docs.google.com/presentation/d/1uue-Mpyw5zSuWfe1qphyhBtrCX4TmBWhN3iMcdYlnek/edit?usp=sharing)

**Events**

* [GopherCon Turkey 2021](https://gophercon.ist/#schedule)
  * [Recording](https://youtu.be/-miC_jnQ_Yk)

## [Parca - Profiling in the Cloud-Native Era](https://youtu.be/ficc6_6RYQk)

For years Google has consistently been able to cut down multiple percentage points in their fleet-wide resource usage every quarter, using techniques described in their “Google-Wide Profiling” paper. Ad-hoc profiling has long been part of the developer’s toolbox to analyze CPU and memory usage of a running process, however, through continuous profiling, the systematic collection of profiles, entirely new workflows suddenly become possible. Matthias and Kemal will start this talk with an introduction to profiling with Go and demonstrate via Conprof - an open-source continuous profiling project - how continuous profiling allows for an unprecedented fleet-wide understanding of code at runtime. Attendees will learn how to continuously profile Go code to help guide building robust, reliable, and performant software and reduce cloud spend systematically.

**Slides**

* [Parca - Profiling in the Cloud-Native Era](https://docs.google.com/presentation/d/1cPdcLLSc_OzlLOnh1vuUaTuVOFjuJ7-NFbC599Pll2I/edit?usp=sharing)

**Events**

* [KubeCon NA 2021](https://youtu.be/ficc6_6RYQk)
  * [Recording](https://youtu.be/ficc6_6RYQk)

## [Absorbing Thanos Infinite Powers for Multi-Cluster Telemetry](https://kccncna20.sched.com/event/ekHk/absorbing-thanos-infinite-powers-for-multi-cluster-telemetry-bartlomiej-plotka-kemal-akkoyun-red-hat-frederic-branczyk-independent)

Thanos is an open-source, CNCF’s Incubated project that horizontally scales Prometheus to create a global-scale highly available monitoring system. It seamlessly extends Prometheus in a few simple steps and it is already used in production by hundreds of companies that aim for high multi-cloud scale for metrics while keeping low maintenance cost. During this talk, core Thanos (and Prometheus) maintainers, will briefly introduce basic ideas behind Thanos and deployment models and use cases. After that, to satisfy more experienced users, they will explain more advanced concepts, tips for running on the scale, and the latest shiny usability improvements. Thanks to the growing community there is much to talk about!

**Slides**
* [Absorbing Thanos Infinite Powers for Multi-Cluster Telemetry](https://docs.google.com/presentation/d/1gMBQ7wLqAae45uGOcaYex-_9s675yzgexW705D7KM1Y/edit#slide=id.ga47ea1e9a6_0_13)

**Events**
* [KubeConNA 2020](https://kccncna20.sched.com/event/ekHk/absorbing-thanos-infinite-powers-for-multi-cluster-telemetry-bartlomiej-plotka-kemal-akkoyun-red-hat-frederic-branczyk-independent)
	* [Recording](https://www.youtube.com/watch?v=6Nx2BFyr7qQ)

## [Are you testing your observability?](http://are-you-testing-your-observability.now.sh)

Observability is the key to understand how your application runs and behaves in action. This is especially vital for distributed environments like Kubernetes, where users run Cloud-Native microservices often written in Go.

Among many other observability signals like logs and traces, the metrics signal has a substantial role. Sampled measurements observed throughout the system are crucial for monitoring the health of the applications and, they enable real-time, actionable alerting. While there are many open-source robust libraries, in various languages, that allow us to easily instrument services for backends like Prometheus, there are still numerous possibilities to make a mistake or misuse those libraries.

During this talk, we discuss valuable patterns and best practices for instrumenting your Go application. The speakers will go through common pitfalls and failure cases while sharing valuable insights and methods to avoid those mistakes. Also, this talk demonstrates, how to leverage Go unit testing to verify the correctness of your observability signals. How it helps and why it is important. Last but not least, the talk covers a demo of the example instrumented Go application based on the experience and projects we maintain.

**Slides**

* [https://github.com/kakkoyun/are-you-testing-your-observability](https://github.com/kakkoyun/are-you-testing-your-observability)

**Events**

* [GoDays Berlin 2020](https://www.godays.io/conferenceday1)
  * [Recording](https://youtu.be/LU6D5cNeHks)
* [FOSDEM 2020](https://fosdem.org/2020/schedule/event/testing_observability/)
  * [Recording](https://www.youtube.com/watch?v=-jF4nWfrY3w)

## [The Zen of Prometheus](https://gitpitch.com/kakkoyun/the-zen-of-prometheus/master?p=presentation#/)

Live Website: [The Zen of Prometheus](https://the-zen-of-prometheus.netlify.app/)

In modern days, we run our applications as loosely coupled microservices on distributed, elastic infrastructure as (mostly) stateless workloads. Under these circumstances, observability is the key to understanding how our applications run and behave in action to deliver highly available and resilient service.

Prometheus is born in such an atmosphere as a solution to satisfy the observability needs of the cloud-native era. Among many other observability signals like logs and traces, metrics play the most substantial role. Sampled measurements observed throughout the system are crucial for monitoring the health of the applications and they enable real-time, actionable alerting. Although the tools in the Prometheus ecosystem make life a lot easier, there are still numerous possibilities to make mistakes or misuse them.

During this talk, Kemal will present several valuable patterns, best practices and idiomatic methods for instrumenting critical services. He will discuss common pitfalls and failure cases while sharing useful insights and methods to avoid those mistakes. Last but not least, he will give tips for writing simple, maintainable and robust alerts that derived from real-life experiences. By doing so he will propose “The Zen of Prometheus”.

**Slides**

* [https://github.com/kakkoyun/the-zen-of-prometheus](https://github.com/kakkoyun/the-zen-of-prometheus)

**Events**

* [PromCon Online 2020](https://promcon.io/2020-online/)
  * [Recording](https://www.youtube.com/watch?v=Nqp4fjw_omU)

## [Building Observable Go Services](https://gitpitch.com/kakkoyun/building-observable-go-applications)

In modern days, we run our applications as loosely coupled micro-services on distributed, elastic infrastructure as (mostly) stateless workloads. Under these circumstances, observability has become a key attribute to understand how our applications run and behave in action, in order to provide highly available and resilient service.

There exist several observability signals, such as “log”, “metric”, “tracing” and “profiling” that can be collected from a running service, which we can also call pillars of observability. Using these signals, we can create real-time, actionable alerts, create panels where we can monitor applications closely, and perform in-depth analysis to find the root of the systems’ failures. Within the Go and CNCF ecosystem, there are a variety of tools that can collect and make these observable signals useful.

During this talk, Kemal will first introduce the tools that can be embedded in the services to make critical services observable, and share the patterns that will enable them to be used efficiently in the applications and services. Moreover,  he will demonstrate how to use these collected signals in real-life scenarios, using tools within the CNCF ecosystem (Loki, Prometheus, OpenTelemetry, Jaeger, Conprof). He also aims to share the methods that are used to build and run applications running under heavy-traffic, and to understand the origin of the problems encountered in running systems.

**Slides**

* [https://github.com/kakkoyun/building-observable-go-services](https://github.com/kakkoyun/building-observable-go-services)

**Events**

* [GopherCon Turkey 2020](https://gophercon.ist/en)
  * [Recording](https://www.youtube.com/watch?v=xkLyM1Gnaus)
