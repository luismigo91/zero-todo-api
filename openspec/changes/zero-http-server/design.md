## Context

The current `native-mongodb-proxy-arch` change introduced a Node.js/Express HTTP proxy that bridges HTTP requests to a Zero CLI binary via temp-file IPC. This was necessary because Zero v0.1.2 lacks socket I/O APIs. However, Zero CAN read from `/dev/stdin` via `std.fs.read` and write to stdout via `world.out.write`. Combined with `socat` (a standard Unix tool that bridges TCP to stdio), Zero can become its own HTTP server — no external language runtime needed.

## Goals / Non-Goals

**Goals:**
- Eliminate Node.js/npm/Express from the dependency chain
- Zero binary handles HTTP parsing, routing, and response serialization
- Use `socat` as the minimal TCP acceptor (single binary, ~200KB on Alpine)
- Maintain identical HTTP API surface (same endpoints, same JSON responses)
- Keep domain/application/infrastructure/presentation layers unchanged
- Docker image: `alpine + socat + jq + curl + Zero binary` (no Node.js)

**Non-Goals:**
- Full HTTP/1.1 compliance (chunked encoding, keep-alive, etc.)
- Concurrent request handling within the Zero process (socat fork handles concurrency)
- HTTPS/TLS termination (delegated to reverse proxy like nginx in production)
- General-purpose HTTP framework — this is a minimal parser for the todo API

## Decisions

### 1. TCP acceptor: socat

**Rationale:** `socat TCP-LISTEN:8080,fork EXEC:./todo-api` spawns a fresh Zero process per connection, piping TCP data to stdin and stdout back to TCP. This is the simplest possible bridge — one line of config, no code. Zero processes are stateless (MongoDB is the state), so forking per request works correctly.

**Alternatives considered:**
- **nc (netcat):** Only handles one connection, no fork mode. Would need a wrapper script with a while loop.
- **inetd/xinetd:** More complex configuration, heavier dependency.
- **Custom C TCP acceptor:** Over-engineering for a bridge that will be replaced when Zero gets socket I/O.

### 2. HTTP parser: minimal byte scanning in Zero

**Rationale:** A minimal HTTP/1.1 parser needs only ~30 lines of Zero code:
1. Read stdin into a fixed buffer (`std.fs.read("/dev/stdin", buf)`)
2. Scan for first ` ` to extract method
3. Scan for second ` ` to extract path
4. Scan for `\r\n\r\n` to find body start
5. Extract body (everything after `\r\n\r\n`)

Zero supports byte indexing (`buf[i]`), `for` loops, and character comparisons (`buf[i] == ' '`). This is sufficient for a minimal parser.

**Alternatives considered:**
- **Shell script pre-parser:** Parse HTTP in bash before calling Zero. Shifts complexity to shell, still has an external dependency.
- **Keep Node.js proxy:** Defeats the purpose. Node.js is the dependency we're removing.

### 3. HTTP response: direct stdout writes

**Rationale:** Zero writes raw HTTP response bytes to `world.out`:
```
world.out.write("HTTP/1.1 200 OK\r\n")
world.out.write("Content-Type: application/json\r\n")
world.out.write("Access-Control-Allow-Origin: *\r\n")
world.out.write("\r\n")
// then read and pipe /tmp/http-body.json content
```

**Alternatives considered:**
- **Response object builder:** Would require `std.json` (unavailable in CLI). Raw writes are simpler.

### 4. CORS and headers: hardcoded in Zero

CORS headers (`Access-Control-Allow-Origin: *`, OPTIONS 204) move from Express middleware into Zero's HTTP response writing. Since there are only 2 headers, this is trivial.

### 5. File I/O for response body: unchanged

Zero still reads `/tmp/http-body.json` (written by shell scripts or Zero's health handler) and pipes it to stdout. The mechanism for getting the body content doesn't change — only the delivery method (stdout instead of proxy-read-file).

## Architecture

```
socat TCP-LISTEN:8080,fork EXEC:./todo-api

For each connection:
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  /dev/stdin ──▶ main.0                                   │
│                   │                                      │
│                   ├── server.parseRequest(buf)           │
│                   │   → method, path, body               │
│                   │                                      │
│                   ├── router.routeRequest(world, ...)    │
│                   │   → domain → infra → MongoDB         │
│                   │   → /tmp/http-body.json              │
│                   │                                      │
│                   └── server.writeResponse(code)         │
│                       → HTTP status line + headers       │
│                       → /tmp/http-body.json content      │
│                                                          │
│  world.out ◀── HTTP response bytes                       │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **Byte-by-byte HTTP parsing is fragile** | Only parse method, path, and body. Don't parse headers. Works for JSON API with known clients (curl, browser fetch). |
| **Fixed buffer overflow** | Use a 4096-byte buffer for stdin. Reject requests larger than the buffer with 413. Todo API requests are tiny. |
| **No keep-alive** | Each request spawns a new Zero process. socat fork already does this. Acceptable for development/low-traffic APIs. |
| **socat not in default Alpine** | `apk add socat` adds ~200KB. Smaller than Node.js (~50MB). |
| **Error handling in raw HTTP** | If parsing fails, write `HTTP/1.1 400 Bad Request` and exit. Simple and clear. |

## Open Questions

1. **OPTIONS preflight**: Should Zero handle CORS preflight directly (return 204 for OPTIONS), or should this be handled by socat/nftables at the TCP level? Decision: Zero handles it in the parser.
2. **Signal handling**: When socat closes the connection, Zero should exit cleanly. Since Zero processes are short-lived (one request), this is natural.
