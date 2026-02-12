---
title: "Fix Go Module Downloads Behind a Corporate VPN"
description: "How to use the GOPROXY pipe separator to gracefully fall back to the public proxy when your corporate Go module proxy is unreachable behind a VPN."
date: 2026-02-12T00:00:00Z
publishDate: 2026-02-12T00:00:00Z
categories:
  - deep-dive
tags:
  - go
  - golang
  - goproxy
  - vpn
  - tooling
  - blog
showToc: true
tocOpen: false
---

If you work at a company that runs its own Go module proxy and you connect through a VPN, you've probably seen this:

```
Get "https://binaries.example.com/google.golang.org/grpc/@v/v1.77.0.mod":
  dial tcp 172.27.5.36:443: i/o timeout
```

The module has nothing to do with your company. It's a public dependency. Yet Go refuses to fetch it from the public proxy and just dies with a timeout. The frustrating part: you know `proxy.golang.org` has the module, and your config lists it as a fallback. So why doesn't it fall through?

## The comma trap

A typical corporate Go setup looks like this:

```bash
export GOPROXY=corp-proxy.internal,https://proxy.golang.org,direct
```

The comma separator between proxies looks harmless, but it controls exactly when Go tries the next proxy in the chain. With commas, Go only falls through on **HTTP 404 or 410** — meaning the proxy responded and said "I don't have this module." Any other error, including TCP timeouts, DNS failures, and 5xx server errors, is treated as a **hard failure**. Go stops and reports the error.

When your VPN is disconnected, the corporate proxy is unreachable. That's a TCP timeout, not a 404. Go never tries `proxy.golang.org`.

## The pipe fix

Go 1.15 introduced the pipe separator (`|`) as an alternative to commas. With a pipe, Go falls through on **any error**, including network failures:

```bash
export GOPROXY="corp-proxy.internal|https://proxy.golang.org,direct"
```

Notice the mix of separators. The pipe between the corporate proxy and the public proxy means "if the corporate proxy is unreachable, try the public one." The comma between the public proxy and `direct` means "only go direct if the public proxy returns 404" — which is the safer default for the last hop.

## Why not use pipes everywhere?

The comma separator exists for a reason: **privacy**. When Go tries to fetch a module from a proxy, it reveals the module path in the request URL. If your corporate proxy is down and you use pipes everywhere, Go would send your private module paths (`github.com/your-company/secret-service`) to `proxy.golang.org` before finally trying to fetch them directly.

The `GOPRIVATE` and `GONOPROXY` environment variables mitigate this. Modules matching those patterns bypass the proxy chain entirely and are fetched directly from source. If you set `GOPRIVATE` correctly, the pipe separator is safe for your use case:

```bash
export GOPRIVATE=github.com/your-company
export GONOPROXY=github.com/your-company
export GONOSUMDB=github.com/your-company,go.internal.example.com
export GOPROXY="corp-proxy.internal|https://proxy.golang.org,direct"
```

With this setup, private modules never touch any proxy. Public modules try the corporate proxy first (fast, cached, available on VPN), fall back to the public proxy on failure, and go direct as a last resort.

## The full picture

Here's how Go resolves a module with this configuration:

```
go get google.golang.org/grpc@v1.77.0

1. Does "google.golang.org/grpc" match GOPRIVATE? No.
2. Try corp-proxy.internal -> TCP timeout (VPN off)
3. Separator is "|" -> fall through on any error
4. Try proxy.golang.org -> 200 OK, module found
5. Done.
```

And for a private module:

```
go get github.com/your-company/secret-service@latest

1. Does "github.com/your-company/secret-service" match GOPRIVATE? Yes.
2. Skip proxy chain entirely.
3. Fetch directly from github.com via git.
4. Done.
```

## One-line fix

If you're in this situation, the fix is a single character change in your shell config:

```diff
- export GOPROXY=corp-proxy.internal,https://proxy.golang.org,direct
+ export GOPROXY="corp-proxy.internal|https://proxy.golang.org,direct"
```

Reload your shell (`source ~/.zshrc`) and Go will gracefully fall back to the public proxy whenever your corporate proxy is unreachable. No more waiting for timeouts to tell you what you already know.
