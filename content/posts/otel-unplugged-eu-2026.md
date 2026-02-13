---
title: "OTel Unplugged EU 2026: Field Notes from the Instrumentation Frontier"
description: "Conference field notes from OTel Unplugged EU 2026 in Brussels — covering Prometheus convergence, the injector vision, eBPF trade-offs, and the future of Go auto-instrumentation."
date: 2026-02-20T00:00:00Z
publishDate: 2026-02-20T00:00:00Z
categories:
  - journal
tags:
  - blog
  - opentelemetry
  - fosdem
  - open-source
  - observability
  - go
  - auto-instrumentation
  - prometheus
  - ebpf
cover:
  image: /uploads/otel_unplugged_2026_crowd.jpeg
  alt: OTel Unplugged EU 2026 — crowd voting on sessions
  caption: OTel Unplugged EU 2026 — session voting at Sparks Meeting, Brussels
---

### Brussels Again, But Make It Unplugged

The day after FOSDEM, about a hundred of us gathered at **Sparks Meeting** on Rue Ravenstein in Brussels for [OTel Unplugged EU 2026](https://opentelemetry.io/blog/2025/otel-unplugged-fosdem/) — an unconference dedicated entirely to OpenTelemetry. Purple stage lights, a mid-century auditorium with wood paneling, and the familiar buzz of people who spend their days thinking about telemetry pipelines. If you know, you know.

![OTel Unplugged agenda projected on stage](/uploads/otel_unplugged_2026_agenda.jpeg)

The format is simple: no prepared talks, no slides. Morning session brainstorming, dot-voting on topics, then self-organizing into **nine rooms across four breakout slots**. You vote with your feet. If a conversation isn't working, you move. It's chaotic, it's honest, and it produces the kind of discussions that polished conference talks rarely achieve.

I spent the day bouncing between sessions on **Prometheus and OpenTelemetry convergence**, the **Injector and Operator**, **OBI/eBPF**, and **auto-instrumentation for Go**. Four rooms, one thread connecting them all: *how do we make applications observable without asking developers to change their code?*

Here's what I learned.

---

### Prometheus Loves OpenTelemetry (It's Complicated)

Prometheus and OpenTelemetry had **two sessions** — one in the morning with end users and contributors, and a follow-up in the afternoon specifically for maintainers. Both were packed. The relationship between these two projects is the kind you'd describe as "it's complicated" on social media.

#### The Resource Attributes Mess

The biggest pain point? Getting OTLP data into Prometheus. **Resource attributes** are the central headache. OTLP has a rich hierarchy — resource, scope, and metric attributes. Prometheus is flat. Bridging these two models means choosing between promoting all attributes, promoting some, or relying on `target_info`. There are too many config options, no consistency across deployments, and the `info` function (using `target_info`) helps but adoption is uneven.

One person described running an observability platform for **over a thousand developers**, most using Prometheus `remote_write`. Some teams want a single OTLP endpoint for logs and metrics, but that just shifts the same "what to promote, what to drop" problem. The frustration was palpable — someone put it bluntly: *"OTel is rewriting everything again."* Different conventions (`.` vs `_`), hard `target_info` joins, and the sense that mature Prometheus semantics (`cluster`, `namespace`) are being duplicated under different names (`k8s.*`).

#### Migration Resistance

Teams recognize the value of OTel's semantic conventions, but the migration path is painful. **Naming inconsistencies** (`.` vs `_`), hard `target_info` joins, and the cognitive overhead of moving from Prometheus's world view to OTel's. Several people mentioned that `PromQL IS AWESOME` (their emphasis, not mine) and that transformation adds overhead that people who come from a Prometheus background don't want to pay.

On the SDK side, OTel measurements require a **hashmap lookup** while Prometheus doesn't. Too many concepts — meter, instrument, aggregation — versus Prometheus's closer alignment to mechanical sympathy. The performance direction being pursued? **Zero allocations, no lookups** — the bound instruments PoC is the concrete step toward closing that gap. Nobody in the room uses delta temporality.

> "People care about observability, not query languages."

#### The Afternoon: Maintainers Chart a Path

The afternoon session brought Prometheus and OTel maintainers together. The mood was constructive. **OTel SDK v2** was discussed as an opportunity for the kind of breaking changes that could simplify the metrics API — a simplified, more performant, but less flexible API. The **Prometheus 3.0** experience was instructive: the maintainers planned for major breakage but ended up with almost none.

Concrete progress: **David Ashpole's [bound instruments PoC in Go](https://github.com/open-telemetry/opentelemetry-go/pull/7790)** — instruments pre-bound to specific attribute sets, eliminating the hashmap lookup. People in the room care about Go and C++ performance, and this could be a game changer.

On the receiver/exporter convergence front: **cAdvisor is considering archiving its Prometheus exporter** and moving all code into the OTel collector. OTel Kubernetes monitoring is broadly adopted, with near-parity to kube-state-metrics. The idea of Prometheus carrying an OTel Collector distribution was floated.

The messaging problem came into sharp focus: as one Prometheus maintainer put it, *"Having joint statements helps towards the perception of working together."* The gap isn't just technical — it's about perception. End users see two projects that look like they're competing, even when the maintainers are collaborating.

**Action items**: use the `#otel-prometheus` Slack channel, meet again in **Amsterdam**, and produce **joint messaging** — "this is built together and is compatible." Who owns that messaging? That's the open question.

---

![Emerging topics sorted on sticky notes during morning brainstorming](/uploads/otel_unplugged_2026_topics.jpeg)

### The Injector: From LD_PRELOAD to `apt install opentelemetry`

Two sessions covered the **Injector and Operator** ecosystem — one focused on the general architecture, the other specifically on **OBI and Injector coordination for Go**. The framing that stuck with me came early: *"OTel instrumentation feels more like a collection of tools than a product."* That's why the Injector exists — to close the gap between what OTel offers and what users expect to just work.

#### Injector vs Operator

The **Injector** is opinionated and out-of-the-box. It aims for **80% coverage with zero configuration**. The **Operator** is for power users who want fine-grained control. Both end users and OTel maintainers were in the room, and more people knew about the Operator than the Injector.

The Injector works via `LD_PRELOAD` — it hooks into process loading to activate SDK instrumentation for Java, .NET, Node.js, and soon Python. It's being used **in production at scale** on Kubernetes. It can detect libc vs musl. Blocking system start during injection? Not perceived as a problem by anyone in the room.

The inevitable question came up: **"What about Go?"** For Go's statically linked binaries, there's no `LD_PRELOAD` equivalent. The answer is either eBPF or compile-time instrumentation. Go remains the special case that requires different thinking.

#### Beyond Kubernetes

There's clear demand for the Injector **outside of Kubernetes** — EC2, bare metal, traditional VMs. Users not on K8s or Docker *"end up using custom Ansibles"* — the packaging gap is real and concrete. System packages (Debian, RPM) are needed, but hosting for them doesn't exist yet. **Red Hat is looking into packaging OTel components.** Multiple projects are independently solving the same packaging problems — signatures, distribution, hosting — which led to a proposal for a **new SIG on OS packaging**.

#### The Vision: One Package to Rule Them All

The afternoon session on OBI and Injector for Go articulated a bold vision:

> Run `apt install opentelemetry` and get everything running — SDKs, Injector, OBI, all coordinated.

This would require massive coordination between instrumentation providers — and it would include the **OTel profiler** alongside the SDKs and Injector. The group discussed how to avoid **double instrumentation** when both OBI and the Injector are present — OBI should detect the Injector and back off (similar to how it already detects other SDKs). A creative proposal emerged: **OBI injecting the Injector** instead of the Operator, since eBPF can intercept process loading natively.

The reality is that **OTel declarative configuration** doesn't cleanly fit either project's model yet. The Injector has its own config format. OBI instruments many applications from a single daemon, which doesn't map neatly to per-application YAML. This is a design problem that needs solving before the `apt install` dream becomes real.

And the question that kept coming back in both sessions — *"What about Go?"* — led naturally into the next room.

---

### eBPF and the Instrumentation Tax

The **OBI/eBPF session** drew a crowd interested in the promise and the trade-offs of non-invasive auto-instrumentation.

![Session brainstorming — Go instrumentation topics cluster together](/uploads/otel_unplugged_2026_stickies.jpeg)

[OBI](https://github.com/open-telemetry/opentelemetry-go-instrumentation) (eBPF-based auto-instrumentation) uses **uprobes** to hook into application functions at the kernel level. No source code modification, no recompilation, no SDK integration. The trade-off? You need **privileges**. `CAP_SYS_ADMIN` or root access is a hard sell for security teams, and the discussion around reducing privilege requirements was lively.

The operational reality came through early: someone described a case where *"the instrumentation was bringing down the pod"* — auto-injection and sidecars destabilizing the very workloads they're supposed to observe. That anecdote set the tone for the rest of the session and led directly to the quote that stuck with me most.

A bright spot: **[eBPF Tokens](https://fosdem.org/2026/schedule/event/3LLHG9-bpf-tokens-safe-userspace-ebpf/)**, a newer Linux facility for safer userspace eBPF, could significantly lower the trust bar. There was optimism in the room about this direction.

OBI isn't just about application tracing. It shines in **network observability** — topology mapping, correlating network stack behavior with application layer events. Someone asked about lock observability — *"Maybe profiling"* was the answer, hinting at the breadth of what people want from eBPF beyond just tracing. And there's an underexplored opportunity around **USDTs** (user-defined static tracepoints). Postgres and MySQL already have them behind flags. Rust makes them easy to add. But we need to convince **popular libraries across more languages** to adopt them.

A broader point was raised: **W3C context propagation** should be pushed into language runtimes and compilers, not just libraries. If the runtime itself understands trace context, the instrumentation story becomes fundamentally simpler.

The most grounded take came during the Go discussion:

> "Document the trade-offs between OBI, compile-time, injector, and SDK. Let people choose. Make them aware of each other and let them work together."

And the reality check:

> "Instrumentation tax is inevitable. Manage it, don't pretend it's free."

The consensus across multiple sessions: **stop treating these approaches as competing camps**. They're complementary layers for different deployment scenarios:

| Approach | Mechanism | Trade-off |
|----------|-----------|-----------|
| **Compile-time** | AST transformation via `-toolexec` | Deepest instrumentation, zero runtime overhead, requires rebuild |
| **eBPF/OBI** | Kernel-level uprobe hooking | No app modification, needs kernel privileges |
| **Injector/SSI** | K8s operator triggering instrumentation | Lowest friction onboarding, abstracts complexity |

On the Kubernetes operations side, there was a concrete proposal: a **CRD for otel-operator** to deploy OBI daemonsets — with config validation and selective node deployment via workload labels. Not theoretical; the group was sketching the API surface.

---

![Community and ecosystem topics — the other half of the brainstorming table](/uploads/otel_unplugged_2026_community.jpeg)

### Patterns Across the Day

Beyond the sessions I attended, three themes kept surfacing throughout the unconference.

#### Ship Faster vs Stable by Default

Two rooms, opposite tensions. One group argued: *"We discourage people from trying. Processes feel rigid. We can only learn if we actually build something."* The Prometheus model — experiment first, let things mature, specify later — was held up as the better feedback loop. The other group was laser-focused on **stability**: feature gates, opt-in experimental features, the pain of breaking changes in semantic conventions. The impatience was clear: *"Less bike-shedding, more doing."*

Both are right. The community is threading a needle between moving fast enough to stay relevant and being stable enough that enterprises trust the project. The gap between these two positions is where a lot of energy gets spent.

#### The Maintainer Crisis

This came up in at least three rooms. **Not enough maintainers, too many PRs, codeowners disappearing.** The JavaScript SIG has an automated script to move inactive maintainers to emeritus after three months. Other SIGs handle it manually. Some SIGs have tried a buddy/mentor system for onboarding new contributors — it helps, but it doesn't scale across all SIGs when the existing maintainers barely have time to review PRs. The phrase that stuck with me:

> "Maintainership is privilege AND responsibility."

And a new problem: as one maintainer put it directly, *"AI slop creates a lot of work for maintainers."* Low-quality AI-generated PRs need review just like everything else, but they rarely lead to productive outcomes — creating a treadmill of review work that burns out the very people the project can't afford to lose.

#### opentelemetry-go-auto: Quietly Fading

During the Go-focused session, someone asked about `opentelemetry-go-auto` — the eBPF-based Go auto-instrumentation project (originally from Alibaba). The answer was frank: the project **"seems in maintenance mode, some of their maintainers are already contributing to OBI."** The group decided to keep it out of the discussions unless those maintainers want to participate. No drama, just the natural evolution of open-source projects. The people moved to where the momentum is.

---

### What Comes Next

The unconference produced concrete next steps across every thread:

- **Prometheus + OTel**: Convergence work continues. Joint messaging, Amsterdam meetup, bound instruments moving forward.
- **Injector**: Merge functionality into the Operator starting with one language. System packages for non-K8s environments.
- **OBI**: Gradual protocol expansion, packaging SIG proposal, exploration of an eBPF-based OTel Collector.
- **Go auto-instrumentation**: Coordinate all three approaches, document trade-offs clearly for end users.

---

### Unplugged

The unconference format works because **the hardest problems in observability right now are not technical** — they're social. Governance, maintenance burden, convergence between projects that grew up independently, vendor-neutrality when vendors are the primary contributors. You can't solve these with a slide deck. You need a room, a whiteboard, and honest conversation.

As I always say — **the hallway track is the real conference.** OTel Unplugged is an entire day of hallway track, and it's exactly what the community needs.

If you want to get involved: join the [CNCF Slack](https://slack.cncf.io/) and find the `#otel-prometheus`, `#otel-ebpf-sig`, and `#otel-go` channels. The SIG meetings are open and listed on the [OTel community repo](https://github.com/open-telemetry/community). Show up, contribute, and help shape the future of observability.

Already looking forward to the next one.
