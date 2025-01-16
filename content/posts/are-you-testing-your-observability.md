---
tags:
  - talks
  - observability
  - go
  - testing
date: "2020-02-15T00:00:00Z"
publishDate: "2020-02-15T00:00:00Z"
title: "talk: Are you testing your observability?"
---

Observability is the key to understand how your application runs and behaves in action. This is especially vital for distributed environments like Kubernetes, where users run Cloud-Native microservices often written in Go.

Among many other observability signals like logs and traces, the metrics signal has a substantial role. Sampled measurements observed throughout the system are crucial for monitoring the health of the applications and, they enable real-time, actionable alerting. While there are many open-source robust libraries, in various languages, that allow us to easily instrument services for backends like Prometheus, there are still numerous possibilities to make a mistake or misuse those libraries.

During this talk, we discuss valuable patterns and best practices for instrumenting your Go application. The speakers will go through common pitfalls and failure cases while sharing valuable insights and methods to avoid those mistakes. Also, this talk demonstrates, how to leverage Go unit testing to verify the correctness of your observability signals. How it helps and why it is important. Last but not least, the talk covers a demo of the example instrumented Go application based on the experience and projects we maintain.

#### [Recording](https://youtu.be/LU6D5cNeHks)

**Slides**
* [Are You Testing Your Observability?](https://github.com/kakkoyun/are-you-testing-your-observability)

**Events**
* [GoDays Berlin 2020](https://www.godays.io/conferenceday1)
  * [Recording](https://youtu.be/LU6D5cNeHks)
* [FOSDEM 2020](https://fosdem.org/2020/schedule/event/testing_observability/)
  * [Recording](https://www.youtube.com/watch?v=-jF4nWfrY3w)