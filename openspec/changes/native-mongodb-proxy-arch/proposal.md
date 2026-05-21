## Why

The current `wasm32-web` architecture serves hardcoded todos with zero persistence — `POST /todos` echoes back the payload without storing it, and there is no `DELETE` or `PATCH`. Real use requires durable storage and full CRUD. Moving to a native target with MongoDB gives us both, while respecting Zero v0.1.2's current capability limits (no socket I/O, no HTTP server).

## What Changes

- **BREAKING**: Replace `wasm32-web` target with `linux-musl-x64` native target
- **BREAKING**: Restructure `src/` from web route handlers to a CLI entry point with internal modules
- Add `GET /todos`, `POST /todos`, `DELETE /todos/:id`, `PATCH /todos/:id` endpoints (full CRUD)
- Add MongoDB persistence via MongoDB Data API (REST/HTTPS) invoked through `std.proc.spawn("curl ...")`
- Add an HTTP proxy layer (Node.js/Express) that receives HTTP requests and delegates to the Zero CLI binary via temp-file IPC
- Add multi-stage Docker build (`FROM alpine`) with `docker-compose.yml` for proxy + MongoDB
- Add `std.env` support for `MONGO_URI` and `MONGO_API_KEY` configuration
- Remove hardcoded todo data

## Capabilities

### New Capabilities

- **native-cli-server**: Zero CLI binary compiled for `linux-musl-x64` that handles todo CRUD logic, reads requests from temp files, invokes MongoDB via curl, and writes JSON responses to temp files.
- **mongodb-persistence**: Integration with MongoDB Data API for persistent CRUD operations on todo items. Includes environment-based configuration and JSON serialization/deserialization of MongoDB documents.
- **http-proxy**: Node.js/Express HTTP server that parses incoming REST requests, spawns the Zero CLI binary with request data in temp files, reads the response, and returns it to the client. Handles CORS and content-type headers.

### Modified Capabilities

- **todo-api**: All existing requirements (health check, list todos, create todo) retain their behavior but shift from wasm32-web static data to native CLI with MongoDB-backed persistence. New requirements added for DELETE and PATCH operations.

## Impact

- `zero.json`: target changes from `wasm32-web` to `linux-musl-x64`, CLI main becomes the server entry point
- `src/routes/*.0`: removed (web route convention no longer applies)
- `src/main.0`: rewritten from stub to full CLI entry point with arg-based dispatch
- New: `src/storage.0`, `src/handlers.0`, `src/types.0` (internal modules)
- New: `proxy/` directory with Node.js HTTP server
- New: `Dockerfile`, `docker-compose.yml`
- Dependencies: Node.js 20+, curl (in container), MongoDB Atlas or local Mongo 7+
