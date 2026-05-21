## 1. HTTP Parser Module (via bash wrapper)

- [x] 1.1 Create `scripts/http-wrapper.sh` — reads HTTP request line, extracts method and path
- [x] 1.2 Wrapper spawns Zero with method+path args (same CLI interface as before)
- [x] 1.3 Wrapper maps Zero exit code to HTTP status line and writes response headers
- [x] 1.4 Wrapper pipes `/tmp/http-body.json` content as HTTP response body
- [x] 1.5 CORS headers included in wrapper response (Content-Type, Access-Control-Allow-Origin)
- [x] 1.6 OPTIONS preflight: handled by Zero returning code 204 (wrapper formats HTTP)

## 2. Main Entry Point

- [x] 2.1 `src/main.0` unchanged — reads from `std.args` as before
- [x] 2.2 socat passes TCP data to stdin; wrapper extracts method+path, calls Zero with args
- [x] 2.3 Request body written by proxy/deleted; body goes through shell scripts directly
- [x] 2.4 Zero calls `router.routeRequest(world, method, path, arg3, arg4)` — unchanged
- [x] 2.5 HTTP response formatted by wrapper from exit code + `/tmp/http-body.json`
- [x] 2.6 Bad requests handled by wrapper (non-zero exit → error response)

## 3. Remove Node.js Proxy

- [x] 3.1 Delete `proxy/` directory entirely
- [x] 3.2 Remove Node.js stages from Dockerfile
- [x] 3.3 Verify `zero check .` passes with no diagnostics (0 errors)

## 4. Docker and Deployment

- [x] 4.1 Update `Dockerfile`: 2-stage build, alpine builder + alpine runtime with socat
- [x] 4.2 Add `apk add socat` to runtime stage
- [x] 4.3 Change CMD to `socat TCP-LISTEN:8080,fork,reuseaddr EXEC:sh /app/scripts/http-wrapper.sh`
- [x] 4.4 Update `docker-compose.yml`: Zero binary is the API service directly

## 5. Integration Verification

- [ ] 5.1 Run `tests/integration.sh` against running container
- [ ] 5.2 Test: GET / → 200 with health JSON
- [ ] 5.3 Test: GET /todos → 200 with array
- [ ] 5.4 Test: POST /todos → 201 with created todo
- [ ] 5.5 Test: DELETE /todos/:id → 200 with deleted
- [ ] 5.6 Test: PATCH /todos/:id → 200 with updated
- [ ] 5.7 Test: OPTIONS /todos → 204 with CORS headers
- [ ] 5.8 Test: GET /unknown → 404
- [ ] 5.9 Test: Malformed request → 400
