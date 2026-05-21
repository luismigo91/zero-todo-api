## Context

The current todo-api runs on `wasm32-web` with hardcoded data. Zero v0.1.2 provides no socket read/write APIs (`std.net` only exposes bootstrap handles, no I/O) and no HTTP client or server runtime. The hosted capability surface that IS functional includes: `std.proc` (spawn subprocesses), `std.fs` (read/write files), `std.env` (environment variables), `std.json` (parse/serialize), and `std.args` (CLI arguments). Hosted capabilities are only available when the build target IS the host — cross-compilation to `linux-musl-x64` from macOS denies them with `TAR002`.

This design bridges the gap between Zero's current capabilities and a functional API: an HTTP proxy handles the web layer, and Zero handles business logic + MongoDB access through shell invocation of `curl`.

## Goals / Non-Goals

**Goals:**
- Full CRUD REST API for todos (GET, POST, DELETE, PATCH)
- MongoDB persistence via Data API (REST over HTTPS)
- Dockerized deployment with `docker-compose` (proxy + MongoDB)
- Multi-stage Docker build where Zero compiles ON Linux (host = `linux-musl-x64`, Proc available)
- Clean separation: proxy = HTTP, Zero = logic, MongoDB = storage

**Non-Goals:**
- Authentication or authorization
- Real-time updates or WebSockets
- Horizontal scaling beyond single container
- MongoDB wire protocol (uses Data API REST, not driver)
- WASM or browser deployment

## Decisions

### 1. Proxy language: Node.js + Express

**Rationale:** Minimal boilerplate (5-10 lines for a route handler), JSON-native, ubiquitous in Docker. The proxy is disposable — it exists only until Zero gains HTTP server capabilities. Python/Flask or Go/nethttp would work equally well; Node.js chosen for simplicity and the user's environment (nvm present).

**Alternatives considered:**
- **Go**: Smaller image but more verbose JSON handling for this use case.
- **Python**: Equivalent simplicity but heavier runtime.
- **Caddy reverse proxy**: Can't transform requests into CLI spawns.

### 2. IPC mechanism: Temp files via /tmp

**Rationale:** Zero v0.1.2 has no stdin reader (`World` provides only `out` and `err`). Command-line arguments (`std.args`) have length limits unsuitable for JSON bodies. Temporary files are the only IPC path that handles arbitrary JSON bodies. The proxy writes the request to `/tmp/req-{uuid}.json`, spawns the Zero binary, and reads `/tmp/res-{uuid}.json`.

**Alternatives considered:**
- **std.args**: Unsuitable for JSON bodies (shell escaping, length limits).
- **std.env**: Unsuitable for request bodies (not designed for structured data).
- **Pipes/stdin**: Not supported by Zero's World capability today.

### 3. MongoDB interface: Data API (REST)

**Rationale:** Zero can spawn `curl` to make HTTPS requests. The MongoDB Data API provides full CRUD via REST endpoints (`/action/find`, `/action/insertOne`, `/action/deleteOne`, `/action/updateOne`). No driver needed, no socket I/O required from Zero.

**Alternatives considered:**
- **MongoDB wire protocol**: Requires socket I/O that Zero doesn't expose.
- **MongoDB C driver via C interop**: Complex, needs libmongoc + libbson + OpenSSL linking.
- **Local mongo with no-auth**: Requires MongoDB listening without TLS, still needs socket I/O.

### 4. Zero CLI structure: Args-based action dispatch

The Zero binary receives two arguments: `--request <path>` and `--response <path>`. It reads the request file, determines the action from the JSON, executes it, and writes the response file. This is a single binary for all CRUD operations rather than separate binaries per endpoint — simpler to manage in Docker.

Request file format:
```json
{ "method": "GET", "path": "/todos", "body": null }
```

Response file format:
```json
{ "status": 200, "body": "[{\"id\":\"...\",\"title\":\"...\",\"done\":false}]" }
```

### 5. Target and Docker build: `linux-musl-x64` on Alpine

**Rationale:** Multi-stage Docker build uses `alpine:latest` as the build stage. Since the build stage IS Linux, `linux-musl-x64` is the host target and has `Proc`, `Fs`, and all hosted capabilities. The compiled binary links against musl libc, making it compatible with the minimal Alpine runtime stage. Final image size is ~12 MB (Zero binary + curl).

### 6. MongoDB Data API structure

Each Zero operation constructs a JSON body for the Data API endpoint and passes it to `curl`:
- **find**: `POST /action/find` with `{ filter: {} }`
- **insertOne**: `POST /action/insertOne` with `{ document: { title, done } }`
- **deleteOne**: `POST /action/deleteOne` with `{ filter: { _id: { $oid: "..." } } }`
- **updateOne**: `POST /action/updateOne` with `{ filter, update: { $set: { ... } } }`

Zero serializes the curl command, spawns it with stdout redirected to a temp file, reads the result with `std.fs.readAllOrRaise`, extracts the relevant data, and builds the API response JSON.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **One process spawn per request** (curl + subprocess overhead) | Acceptable for low-traffic APIs. Each request spawns 2 processes (curl for MongoDB + the Zero binary itself). Latency ~50-200ms in-container. |
| **Temp file races** under concurrent requests | Each request uses a UUID-based unique temp file path. Old files cleaned up periodically or rely on /tmp being ephemeral in containers. |
| **curl dependency in production image** | Alpine includes curl; the `apk add curl` in the Dockerfile adds ~2 MB. |
| **MongoDB Data API requires Atlas or Realm** | For local dev without Atlas, use `mongosh` or a local REST proxy. Not addressed in this change — assumes Atlas Data API is available. |
| **Error handling across process boundaries** | Zero writes error JSON to the response file. Proxy reads it and returns appropriate HTTP status. curl failures are detected via `std.proc.exitCode`. |
| **No TLS from Zero itself** | curl handles TLS transparently. Zero never touches sockets directly. |

## Open Questions

1. **Local dev without Atlas**: Can use a local MongoDB instance with `mongod` + a REST interface layer, or run the Data API locally via Atlas CLI. Not in scope for this change.
2. **Idempotency keys**: Not needed for a todo app.
3. **Response body handling for large datasets**: Data API responses are capped. Pagination not needed for a todo list but should be considered if dataset grows.
