---
title: "See it run: OBI and the eBPF profiler without Kubernetes"
description: "Run OBI and the OpenTelemetry eBPF profiler against one untouched Go server with Docker Compose: a trace, CPU samples, and the errors I hit."
date: 2026-07-25T00:00:00Z
publishDate: 2026-07-25T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - ebpf
  - profiling
showToc: true
tocOpen: false
---
Parts 2 and 4 of this series describe what OBI (OpenTelemetry eBPF Instrumentation) and the OpenTelemetry eBPF profiler can do. Here we make them do it with Docker Compose and no Kubernetes: one Go server nobody touches, OBI watching its requests, the profiler watching its CPU. We'll follow one request, `GET /orders/42`, and see it twice, first as a trace and then as CPU samples.

This is a companion to the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series, between [Part 4](/posts/continuous-profiling-go-without-code-changes/) and [Part 5](/posts/go-runtime-futures-flight-recording-usdt/), and the hands-on side of [my GopherCon UK talk](/talks/instrument-go-without-changing-a-single-line/). It all ran on one machine: a Colima VM (Ubuntu 24.04, kernel 6.8.0, linux/arm64, 2 CPUs, 2 GB) on an M4 Max laptop, not Docker Desktop. It's one run, a demo and not a benchmark.

## A server with nothing in it

Here is the whole service. Its handler hashes the order ID 200,000 times so the profiler has CPU to sample, and `//go:noinline` keeps `lookupOrder` on the stack, as `checkout` does in Part 4.

```go
package main

import (
	"crypto/sha256"
	"fmt"
	"log"
	"net/http"
)

//go:noinline
func lookupOrder(id string) string {
	sum := sha256.Sum256([]byte(id))
	for range 200_000 {
		sum = sha256.Sum256(sum[:])
	}
	return fmt.Sprintf("order %s, checksum %x", id, sum[:4])
}

func main() {
	http.HandleFunc("GET /orders/{id}", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, lookupOrder(r.PathValue("id")))
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

No OpenTelemetry, no pprof. The `GET /orders/{id}` pattern is [Go 1.22 routing](https://go.dev/blog/routing-enhancements). The Dockerfile builds with Go 1.27.1 and strips the binary, as in Part 4, into an empty image:

```dockerfile
FROM golang:1.27.1 AS build
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -ldflags='-s -w' -o /orders .

FROM scratch
COPY --from=build /orders /orders
ENTRYPOINT ["/orders"]
```

Did the stripping work? I copied the binary out with `docker cp`:

```console
$ go tool nm orders-linux-arm64
reading orders-linux-arm64: no symbol section
reading orders-linux-arm64: no symbols
$ strings orders-linux-arm64 | grep -E '^main\.'
main.lookupOrder
main.main
main.main.func1
```

No symbols, yet the function names are still in the file. That is `.gopclntab` again, and the profiler will read it later. (Yes, foreshadowing. 👀) First, the cast.

## The compose file

Four more services join the server: [Jaeger 2.21.0](https://www.jaegertracing.io/docs/2.21/getting-started/) for traces (as in Part 6), a `curl` loop sending `GET /orders/42` a few times a second, [OBI v0.10.0](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/releases/tag/v0.10.0) and the profiler. Here is the whole file:

```yaml
name: see-it-run

services:
  orders:
    build: ./app

  jaeger:
    image: jaegertracing/jaeger:2.21.0
    ports:
      - "16686:16686"

  load:
    image: curlimages/curl:8.11.1
    entrypoint: ["/bin/sh", "-c"]
    command:
      - 'while true; do curl -s http://orders:8080/orders/42 > /dev/null; sleep 0.2; done'
    depends_on:
      - orders

  obi:
    image: otel/ebpf-instrument:v0.10.0
    privileged: true
    pid: "service:orders"
    environment:
      OTEL_EBPF_OPEN_PORT: "8080"
      OTEL_EXPORTER_OTLP_ENDPOINT: http://jaeger:4318
    depends_on:
      - orders
      - jaeger

  profiler:
    image: otel/opentelemetry-collector-ebpf-profiler:0.160.0
    privileged: true
    pid: host
    command:
      - --config=/etc/profiler.yaml
      - --feature-gates=+service.profilesSupport
    volumes:
      - /sys/kernel/debug:/sys/kernel/debug:ro # tracepoints are looked up here
      - profiles:/out
    configs:
      - source: profiler
        target: /etc/profiler.yaml
    depends_on:
      - orders

configs:
  profiler:
    content: |
      receivers:
        profiling:
      exporters:
        debug:
          verbosity: detailed
        file:
          path: /out/profiles.json
      service:
        pipelines:
          profiles:
            receivers: [profiling]
            exporters: [debug, file]

volumes:
  profiles:
```

OBI's `pid: "service:orders"` puts it in the server's PID namespace, so the server is PID 1 to it. [`OTEL_EBPF_OPEN_PORT`](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/pkg/obi/config.go#L381) tells it to instrument whichever process has port 8080 open. The [OBI Docker docs](https://opentelemetry.io/docs/zero-code/obi/setup/docker/) ask for the host PID namespace; sharing only the server's was enough here.

The profiler gets `pid: host` to sample the whole node, and the feature-gate flag its [README](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/blob/v0.0.202633/README.md) uses. Collector `0.160.0` is the newest that [bundles profiler v0.0.202633](https://github.com/open-telemetry/opentelemetry-collector-releases/blob/v0.160.0/distributions/otelcol-ebpf-profiler/manifest.yaml), the tag Part 4 cites. Its config is inline because bind-mounting a file from `/tmp` into my VM gave me an empty directory.

First, what OBI makes of the server.

## OBI finds the server

Compose builds and starts everything. Then we read OBI's log:

```console
$ docker-compose up -d --build
$ docker-compose logs obi | grep "instrumenting process"
obi-1  | time=2026-10-04T07:50:01.412Z level=INFO msg="instrumenting process" component=discover.traceAttacher cmd=/orders pid=1 ino=1071739 type=go service="" logenricher=false
```

OBI found `/orders`, recognised a Go binary (`type=go`) and attached, with no rebuild. The server never noticed: I restarted OBI 90 seconds later, it attached again, and the server's start time stayed at `07:49:59`. Now Jaeger's query API, condensed to the fields that matter:

```console
$ curl -s 'localhost:16686/api/v3/traces?query.service_name=orders&query.num_traces=1&query.start_time_min=...&query.start_time_max=...'
span 'in queue' kind=1 parent='88d93c2068b37f04' duration=0.02ms
span 'processing' kind=1 parent='88d93c2068b37f04' duration=11.61ms
span 'GET /orders/{id}' kind=2 parent='-' duration=11.63ms
    http.request.method = GET
    http.response.status_code = 200
    http.route = /orders/{id}
    url.path = /orders/42
```

One server span (kind 2) with method, status and path, plus two internal spans, `in queue` and `processing`. `http.route` is the registered pattern; `url.path` is the raw path. Give traces 15 to 20 seconds to show up. On my first attempt nothing appeared in 45 seconds, though OBI's log looked fine. Recreating the container (with debug logging on) fixed it, and I never found the cause.

A caller's trace is continued too. I sent a `traceparent` header and asked Jaeger for the trace ID I had chosen: the server span carried it, and its parent was the span ID I sent. Passing context on to outgoing calls needs the extra capabilities [Part 2](/posts/obi-ebpf-auto-instrumentation-go/#what-it-requires) lists. I didn't turn that on, so it's untested here.

That's the trace. The same request also burned CPU, and a trace can't tell us where.

## The profiler reads a stripped binary

Why not `net/http/pprof`? It needs an import and a redeploy. The eBPF profiler already watches every process on the node. Its first start on my VM failed:

```console
Error: cannot start pipelines: failed to start "profiling" receiver: failed to attach scheduler monitor: failed to configure tracepoint on tracer.hookPoint{group:"sched", name:"sched_process_free"}: neither debugfs nor tracefs are mounted
```

The VM has debugfs, but a privileged container can't see it, hence the `/sys/kernel/debug` mount in the compose file. With it the profiler reports "Everything is ready" and prints a profile every five seconds. Here are two lines of the output, our server and the profiler's tag:

```text
     -> process.executable.path: Str(/orders)
InstrumentationScope go.opentelemetry.io/ebpf-profiler v0.0.202633
```

Our server is in there, next to `dockerd`, `containerd`, OBI and the profiler itself. The debug output refers to frames by index, so we read the `file` exporter's JSON. This script (`lookup-share.py`) prints the first `orders` stack containing `main.lookupOrder`, then counts how many samples do:

```python
import json, sys

hit = total = 0
first = None
for line in open(sys.argv[1]):
    doc = json.loads(line)
    d = doc["dictionary"]
    s = d["stringTable"]

    def frames(stack):
        locs = d["stackTable"][stack]["locationIndices"]
        return [s[d["functionTable"][ln["functionIndex"]]["nameStrindex"]]
                for i in locs for ln in d["locationTable"][i].get("lines", [])]

    for rp in doc["resourceProfiles"]:
        res = {s[a["keyStrindex"]]: a["value"] for a in rp["resource"]["attributes"]}
        exe = res.get("process.executable.name", {}).get("stringValueStrindex")
        if exe is None or s[exe] != "orders":
            continue
        for sp in rp["scopeProfiles"]:
            for prof in sp["profiles"]:
                for sample in prof.get("samples", []):
                    total += 1
                    names = frames(sample["stackIndex"])
                    if "main.lookupOrder" in names:
                        hit += 1
                        first = first or names
print("\n".join(first))
print(f"{hit} of {total} samples from orders have main.lookupOrder on the stack")
```

```console
$ python3 lookup-share.py profiles.json
crypto/internal/fips140/sha256.blockSHA2
crypto/internal/fips140/sha256.(*Digest).Write
crypto/internal/fips140/sha256.(*Digest).checkSum
crypto/internal/fips140/sha256.(*Digest).Sum
crypto/sha256.Sum256
main.lookupOrder
main.main.func1
net/http.HandlerFunc.ServeHTTP
net/http.(*ServeMux).ServeHTTP
net/http.serverHandler.ServeHTTP
net/http.(*conn).serve
net/http.(*Server).Serve.gowrap3
runtime.goexit
100 of 106 samples from orders have main.lookupOrder on the stack
```

There's the thought we held on to. The binary has no symbol table, yet the stack reads `main.lookupOrder`, `net/http.(*conn).serve` and `runtime.goexit`, because `.gopclntab` is still in the file. Read from the top, that's a text flame graph: 100 of 106 samples were in our hashing loop, called from our handler, called from `net/http`. Drawing it needs an OTLP profiles backend; the README offers [devfiler](https://github.com/elastic/devfiler) (a development tool, it says) and Pyroscope.

## What this doesn't show

A Compose file is a Kubernetes DaemonSet in costume, and [Part 6](/posts/zero-touch-go-observability-agent-actionable/) has the dry-run route for a cluster. The signal is Alpha, and this was one request shape on an idle VM. It shows the plumbing works. Your fleet's verdict is a separate experiment.

Versions, links and commands checked on 4 October 2026.

## Try it

I used the standalone `docker-compose` 5.6.0 binary because my `docker compose` plugin link was broken; either spelling works. Put `compose.yaml` next to an `app/` directory with `main.go`, the Dockerfile, and a `go.mod` (`module example.com/orders`, `go 1.27`). Then:

```bash
docker compose up -d --build
docker compose logs obi | grep "instrumenting process"
docker compose logs profiler | grep "Everything is ready"
docker compose down -v
```

Jaeger's UI is on `localhost:16686`. Try one of your own stripped binaries and see what names come back.

One request, two signals, zero edits to the server. It's still the same 24 lines, and it doesn't know anyone is watching. Go see what yours looks like from the outside. 🔭
