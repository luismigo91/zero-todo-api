## Why

The current architecture requires a Node.js proxy (55 lines of Express) solely because Zero can't accept TCP connections. But Zero CAN read `/dev/stdin` and write to `world.out`. Using `socat` as a minimal TCP→stdio bridge, Zero becomes the HTTP server itself — parsing requests from stdin, writing responses to stdout. This eliminates Node.js, npm, and Express as dependencies, reducing the production image surface to: `alpine + socat + jq + curl + Zero binary`.

## What Changes

- **BREAKING**: Remove `proxy/` directory (Node.js + Express proxy)
- Add `src/server.0` — HTTP parser that reads from `/dev/stdin`, extracts method/path/body, and writes HTTP responses to stdout
- Update `src/main.0` — read request from stdin instead of CLI args, call router, write HTTP response to stdout
- Update `Dockerfile` — remove Node.js stages, add `socat` to runtime, change CMD to `socat TCP-LISTEN:8080,fork EXEC:./todo-api`
- Update `docker-compose.yml` — remove Node.js proxy service, Zero binary becomes the API service directly
- `tests/integration.sh` — unchanged (same HTTP interface)
- Domain, application, infrastructure, and presentation layers — **unchanged**

## Capabilities

### New Capabilities

- **http-parser**: Minimal HTTP/1.1 request parser in Zero that reads from `/dev/stdin`, extracts method, path, and body from raw bytes, and writes HTTP response format to stdout.

### Modified Capabilities

- **native-cli-server**: The CLI binary becomes an HTTP server process (reads stdin, writes stdout) instead of a CLI invoked per-request with arguments. Routing and handler logic unchanged.

### Removed Capabilities

- **http-proxy**: The Node.js Express proxy is removed. Its responsibilities (HTTP parsing, CORS, content-type headers) move into Zero's `src/server.0`.

## Impact

- `proxy/` directory: deleted
- `src/main.0`: rewritten to read stdin instead of args, write HTTP responses
- `src/server.0`: new module with HTTP parse/serialize helpers
- `Dockerfile`: simplified to 2-stage (build Zero → alpine + socat + scripts)
- `docker-compose.yml`: proxy service removed, Zero binary is the API service
- Zero dependencies: unchanged (std.fs, std.proc, std.mem)
- External dependencies: `+socat`, `-node`, `-npm`, `-express`
