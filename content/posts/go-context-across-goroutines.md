---
title: "Context across goroutines and connections"
description: "Three different jobs hide behind the word propagation in Go: copying goroutine storage, keeping context.Context, and carrying trace headers between connections."
date: 2026-07-27T00:00:00Z
publishDate: 2026-07-27T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - tracing
  - auto-instrumentation
showToc: true
tocOpen: false
---

We're going to follow one request, `GET /orders/42`, and ask what "propagation" means at each hop. Three different jobs hide behind that word, the tools in this series do different ones, and the request's own data falls into the gaps between them. The cheapest way to see a gap is a short Go program.

This is a companion to the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series, between [Part 4](/posts/continuous-profiling-go-without-code-changes/) and [Part 5](/posts/go-runtime-futures-flight-recording-usdt/). The series accompanies my [GopherCon UK talk](/talks/instrument-go-without-changing-a-single-line/). [Part 1](/posts/why-go-cant-be-monkey-patched/#the-goroutine-problem) showed tools hacking a field into `g`. Here we look at what that field holds, what it can't, and who does the rest.

Disclosure: I work at Datadog and I'm one of the maintainers of otelc, the OpenTelemetry compile-time instrumentation tool.

## What falls out of a goroutine

Our request arrives with a context: a trace ID stored as a value, a one-second deadline, and, because the client hung up, a cancellation. The program below hands that context to one goroutine and `context.Background()` to another. The second is what a function ends up with when its signature has no `ctx` parameter and nothing else to go on. Each goroutine prints what it can learn about the request:

```go
package main

import (
	"context"
	"fmt"
	"time"
)

type traceKey struct{}

// inGoroutine runs the report in a new goroutine and waits for it.
func inGoroutine(name string, ctx context.Context) {
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, hasDeadline := ctx.Deadline()
		fmt.Printf("%-12s value=%v deadline=%v err=%v\n",
			name, ctx.Value(traceKey{}), hasDeadline, ctx.Err())
	}()
	<-done
}

func main() {
	ctx := context.WithValue(context.Background(), traceKey{}, "trace-abc123")
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	cancel() // the client hung up

	inGoroutine("request ctx:", ctx)
	inGoroutine("fresh ctx:", context.Background())
}
```

Go 1.27.1 prints this (one run, one machine, though the output doesn't depend on timing):

```text
request ctx: value=trace-abc123 deadline=true err=context canceled
fresh ctx:   value=<nil> deadline=false err=<nil>
```

The first goroutine knows the lot because we handed it the context. The second knows nothing: no value, no deadline, and `ctx.Err()` is nil even though the client left. Threading `ctx` through by hand fixes it, and that's the code change this series is trying to avoid. A tool that can't ask us to do that needs somewhere else to keep the request.

## Job one: copy a slot when a goroutine starts

Orchestrion (Datadog's `-toolexec` tool) keeps that somewhere else in a `__dd_gls_v2` field on `runtime.g`, which [part 1](/posts/why-go-cant-be-monkey-patched/#the-goroutine-problem) walks through. Its [aspect](https://github.com/DataDog/dd-trace-go/blob/v2.9.1/internal/orchestrion/gls.orchestrion.yml) adds the field and clears it in `goexit1`, and neither rule touches the code that starts a goroutine, so the slot does not follow `go`. The `TODO` part 1 quotes from the context stack is still there at v2.9.1. I read both files at v2.0.0 and v2.9.1, and they match.

otelc copies on `go`. The [runtime rule at v1.1.0](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/instrumentation/runtime/otelc.yaml) (the `instrumentation/runtime/` directory is identical at v1.0.1, the series pin) injects a deferred function into `newproc1`, the runtime function that builds a new goroutine, to copy the two fields it adds to `g`, `otel_trace_context` and `otel_baggage_container`. Re-indented the way gofmt would print it, the injected code is:

```go
defer func() {
	_unnamedRetVal0.otel_trace_context = propagateOtelContext(callergp.otel_trace_context)
	_unnamedRetVal0.otel_baggage_container = propagateOtelContext(callergp.otel_baggage_container)
}()
```

`_unnamedRetVal0` is the new goroutine and `callergp` is its creator. [`propagateOtelContext`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/instrumentation/runtime/runtime_gls.go#L28-L36) returns nil for nil, calls `Clone()` when the value has one, and otherwise hands over the same reference. The one `Clone` in the SDK instrumentation is on the [span stack](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/instrumentation/go.opentelemetry.io/otel/sdk/trace/otel_trace_context.go#L264): it keeps the innermost live span and drops the rest, so the child starts with a stack of one. The baggage slot is copied too, but in the v1.1.0 tree the only write I found is a reset to nil, so I can't tell you what it carries today.

Reading it back, a [hook on `trace.SpanFromContext`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/instrumentation/go.opentelemetry.io/otel/trace/hook.go#L15) swaps in the goroutine's span when the context has no valid one. What crosses a `go` statement is the parent's current span, and a span is not the request.

## Job two: keep the request's own context

Our program already showed the difference. A `context.Context` carries values, a deadline and a cancellation signal, and the goroutine with the fresh context lost all three. Give that goroutine an otelc-style slot and, going by the hook's code, `SpanFromContext(context.Background())` returns the right parent span, so the trace tree stays whole. `ctx.Err()` is still nil and the deadline is still missing. The trace repaired itself and the request didn't.

My opinion: tools have been solving two problems as one. "Which span is my parent?" is a question a goroutine slot can answer. "Is my caller still waiting, and what did it attach to the request?" needs the context itself. The [`context` package](https://github.com/golang/go/blob/go1.27.1/src/context/context.go#L50) says values are for "request-scoped data that transits processes and APIs", which is precisely the data a span-only copy drops.

Let's leave the process and follow the request onto the wire.

## Job three: incoming connection to outgoing connection

At library level the job is spelled out in code. The [otelhttp handler](https://github.com/open-telemetry/opentelemetry-go-contrib/blob/instrumentation/net/http/otelhttp/v0.72.0/instrumentation/net/http/otelhttp/handler.go#L98) extracts trace headers from the incoming request into its context. The [transport](https://github.com/open-telemetry/opentelemetry-go-contrib/blob/instrumentation/net/http/otelhttp/v0.72.0/instrumentation/net/http/otelhttp/transport.go#L266) injects them into the outgoing request from `r.Context()`. Every link in that chain needs the context threaded. As I read it, that is the gap the `SpanFromContext` fallback from job one is built for.

OBI (OpenTelemetry eBPF Instrumentation) does it from outside the process, and here it helps to separate two modes. The [v0.10.0 design doc](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/devdocs/context-propagation.md) describes kernel-side propagation, off by default (`OTEL_EBPF_BPF_CONTEXT_PROPAGATION`). With `headers` it injects a `Traceparent` header into plaintext HTTP, and with `tcp` it adds a TCP option to any TCP traffic. On the way in, it parses whichever one arrived. The [security page](https://opentelemetry.io/docs/zero-code/obi/security/) (unversioned) lists `CAP_NET_ADMIN` for the trace-context-propagation programs.

For Go there is a second mode. The same design doc says a uprobe tries `bpf_probe_write_user` to write the header straight into Go's HTTP buffer and leaves the header to the kernel-side injector if that fails. The security page lists `CAP_SYS_ADMIN` for "library-level Go trace-context propagation".

How does OBI know which outgoing call belongs to which incoming request? It hooks the same function otelc does. [Two uprobes on `runtime.newproc1`](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/bpf/gotracer/go_runtime.c#L114-L185) record each new goroutine's parent in a BPF map, keyed by goroutine address instead of a field in `g`. When an HTTP client call starts, OBI [walks up that chain](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/bpf/gotracer/go_common.h#L151-L186) until it finds a goroutine serving a request.

OBI carries trace and span IDs in BPF maps keyed by goroutine. In the Go probes I read (v0.10.0) it uses no request-context values, so the deadline, cancellation and values stay where they were. For a tool that changes nothing that's a fair deal, and it leaves that data behind. Which brings us to the one place neither route can reach: the runtime.

## What a runtime would need

What follows is my opinion, start to finish. Part 5 looks at [the same gap](/posts/go-runtime-futures-flight-recording-usdt/#observing-isnt-propagating) from another side: my tracing fork rides on `context.Context`, so the context still has to be threaded.

The runtime already copies one slot when a goroutine starts: [`g.labels`](https://github.com/golang/go/blob/go1.27.1/src/runtime/proc.go#L5403), which [`runtime/pprof` documents](https://github.com/golang/go/blob/go1.27.1/src/runtime/pprof/runtime.go#L39) as "A new goroutine inherits the labels of the goroutine that created it". It holds string pairs for the profiler, and the [OTel profiling OTEP](https://github.com/open-telemetry/opentelemetry-specification/blob/bd83138a95b6ca31384f0cb2490b2069bdec26f5/oteps/profiles/4947-thread-ctx.md#alternative-for-go-support) says "we foresee Go readers will directly read pprof labels". That is precedent for an inherited slot, but the slot belongs to the profiler.

What I'd want is goroutine-associated storage that a new goroutine inherits and that does not lose the request's context data: the values, the deadline and the cancellation, not only a span. That raises questions I can't answer: copy or share on `go`, who clears it when the goroutine exits, what happens when two tools want the one slot, and what it costs on every `go` statement. I have no design, and anything touching `newproc1` needs the Go team's agreement. Until someone builds that, propagation stays unsolved, and we keep choosing which of the three jobs to lose. Enough opinion from me, though. Time to run something.

Versions, links and commands checked on 2 October 2026.

## Try it

Save the program above as `main.go`, then run it:

```bash
go mod init demo
go run .
```

To read what otelc copies, print the rule yourself:

```bash
gh api 'repos/open-telemetry/opentelemetry-go-compile-instrumentation/contents/instrumentation/runtime/otelc.yaml?ref=v1.1.0' --jq .content | base64 -d
```

Then go hunting in your own services for the function three frames down that never got a `ctx`. It's there. 🔍
