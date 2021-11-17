---
title: Talks
date: 2020-03-01T01:57:45.000+01:00

---
This page lists the recorded talks that I have given so far. Not much but it's a start.

### For a more up-to-date list, check [this YouTube playlist](https://www.youtube.com/playlist?list=PL3P7-fer_ILLtH_ZtQDQhDAEgTo5r9OnB) or [https://github.com/kakkoyun/talks](https://github.com/kakkoyun/talks). 

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
