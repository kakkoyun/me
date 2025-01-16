---
tags:
  - talks
  - prometheus
  - observability
date: "2020-09-20T00:00:00Z"
publishDate: "2020-09-20T00:00:00Z"
title: "talk: The Zen of Prometheus"
---

Live Website: [The Zen of Prometheus](https://the-zen-of-prometheus.netlify.app/)

In modern days, we run our applications as loosely coupled microservices on distributed, elastic infrastructure as (mostly) stateless workloads. Under these circumstances, observability is the key to understanding how our applications run and behave in action to deliver highly available and resilient service.

Prometheus is born in such an atmosphere as a solution to satisfy the observability needs of the cloud-native era. Among many other observability signals like logs and traces, metrics play the most substantial role. Sampled measurements observed throughout the system are crucial for monitoring the health of the applications and they enable real-time, actionable alerting. Although the tools in the Prometheus ecosystem make life a lot easier, there are still numerous possibilities to make mistakes or misuse them.

During this talk, Kemal will present several valuable patterns, best practices and idiomatic methods for instrumenting critical services. He will discuss common pitfalls and failure cases while sharing useful insights and methods to avoid those mistakes. Last but not least, he will give tips for writing simple, maintainable and robust alerts that derived from real-life experiences. By doing so he will propose “The Zen of Prometheus”.

#### [Recording](https://www.youtube.com/watch?v=Nqp4fjw_omU)

**Slides**
* [The Zen of Prometheus](https://github.com/kakkoyun/the-zen-of-prometheus)

**Events**
* [PromCon Online 2020](https://promcon.io/2020-online/)
  * [Recording](https://www.youtube.com/watch?v=Nqp4fjw_omU)