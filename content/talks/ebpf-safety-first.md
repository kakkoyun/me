---
categories:
  - talks
tags:
  - talks
  - eBPF
  - rust
  - go
date: "2022-05-10T00:00:00Z"
publishDate: "2022-05-10T00:00:00Z"
title: "talk: eBPF? Safety First!"
cover:
  image: https://img.youtube.com/vi/oWHQrlE2-G8/maxresdefault.jpg
  alt: eBPF? Safety First!
  caption: eBPF? Safety First!
---

eBPF being a promising technology is no news. And C is the defacto choice for writing eBPF programs. The act of writing C programs in an error-prone process. Even the eBPF verifier makes life a lot easier; it is still possible to write unsafe programs and make trivial mistakes that elude the compiler but are detected by the verifier in the load time, which are preventable with compile-time checks. It is where Rust comes in. Rust is a language designed for safety. Recently the Rust compiler gained the ability to compile to the eBPF virtual machine, and Rust became an official language for Linux. We discover more and more use cases where eBPF can be helpful. We find more efficient ways to build safe eBPF programs that are parallel to these developments. We will demonstrate how we made applications combined with Rust in the data plane for more safety and Go in the control plane for a higher development pace to target Kubernetes for security, observability and performance tuning.

#### [Recording](https://youtu.be/oWHQrlE2-G8)

**Slides**

* [eBPF? Safety First!](https://docs.google.com/presentation/d/1hKqxAC9aaWLPM4xwXyXuK5cp2LBAewOVqZ05qjLNnK8/edit?usp=sharing)

**Events**

* [Cloud-Native eBPF Day EU 2022](https://sched.co/zrPZ)
  * [Recording](https://youtu.be/oWHQrlE2-G8)
