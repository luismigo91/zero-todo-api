## 1. Project Setup

- [x] 1.1 Update `zero.json` targets from `wasm32-web` to `linux-musl-x64` native, keep CLI as main entry
- [x] 1.2 Create `src/main.0` with API routing and dispatch logic (types inlined, no std.json needed for CLI)
- [x] 1.3 Remove `src/routes/` directory (web route convention no longer applies)
- [x] 1.4 MongoDB operations via shell scripts (`scripts/mongo-*.sh`) using jq + curl
- [x] 1.5 CRUD handlers integrated into `src/main.0` dispatch function
- [x] 1.6 Verify `zero check .` passes on host target with new structure

## 2. MongoDB Storage Layer

- [x] 2.1 Create `scripts/mongo-find.sh` — lists todos via Data API
- [x] 2.2 Create `scripts/mongo-insert.sh` — creates todo via Data API
- [x] 2.3 Create `scripts/mongo-delete.sh` — deletes todo via Data API
- [x] 2.4 Create `scripts/mongo-update.sh` — updates todo via Data API
- [x] 2.5 Shell scripts use jq for safe JSON construction and response parsing
- [x] 2.6 Zero writes request data to temp files (`/tmp/req-body.json`, `/tmp/todo-id.txt`)
- [x] 2.7 Shell scripts write result to `/tmp/http-body.json`; handle error exit codes (2=not found)

## 3. CLI Entry Point

- [x] 3.1 `src/main.0` reads method, path, and optional body from `std.args`
- [x] 3.2 Request routing via string matching with Span<u8> comparisons
- [x] 3.3 Request body passed as CLI argument; written to temp file by dispatch
- [x] 3.4 Dispatch logic: matches method+path, routes to shell script spawn
- [x] 3.5 Health check (`GET /`) returns static JSON written to /tmp/http-body.json
- [x] 3.6 Unknown paths return 404 via error JSON

## 4. CRUD Handlers

- [x] 4.1 `GET /todos` → spawn `scripts/mongo-find.sh`
- [x] 4.2 `POST /todos` → write body, spawn `scripts/mongo-insert.sh`
- [x] 4.3 `DELETE /todos/:id` → write id, spawn `scripts/mongo-delete.sh`
- [x] 4.4 `PATCH /todos/:id` → write id + body, spawn `scripts/mongo-update.sh`
- [x] 4.5 Health check (`GET /`) returns metadata with status 200

## 5. HTTP Proxy (Node.js)

- [x] 5.1 Create `proxy/` directory with `package.json` (express dependency)
- [x] 5.2 Create `proxy/index.js` with Express server on port 8080
- [x] 5.3 Proxy spawns Zero CLI with method, path, and body as arguments
- [x] 5.4 Proxy reads `/tmp/http-body.json` for response body
- [x] 5.5 Proxy maps exit codes to HTTP status (0→200, 2→404, other→500)
- [x] 5.6 CORS headers set on all responses
- [x] 5.7 JSON content type header on all responses
- [x] 5.8 Proxy is thin: HTTP ↔ CLI bridge, no business logic

## 6. Docker Deployment

- [x] 6.1 Create `Dockerfile` with multi-stage build: alpine + zero + node
- [x] 6.2 Create `docker-compose.yml` with api + mongo services
- [x] 6.3 Configure `MONGO_DATA_API_URL` and `MONGO_API_KEY` via environment

## 7. Upcoming

- [x] 7.1 Write `tests/integration.sh` — full CRUD flow with curl
- [ ] 7.2 Run: create → list → update → delete → list empty (requires MongoDB Data API)
- [ ] 7.3 Run edge cases: missing title (400), delete non-existent (404), update non-existent (404)
- [x] 7.4 Verify `zero check .` passes with no diagnostics (0 errors)
