---
name: zero-web
description: Build web APIs and route handlers with Zero. Covers web targets, route structure, Request/Response surfaces, JSON handling, and WASM deployment constraints.
---

# Zero Web

## What Zero Web Is

Zero compiles web route handlers to WASM (`wasm32-web`). Each `.0` file in `src/routes/` exports HTTP method functions. No framework, no JS runtime tax — `frameworkTaxBytes: 0`.

## Manifest

```json
{
  "package": { "name": "my-api", "version": "0.1.0" },
  "targets": {
    "cli": { "kind": "exe", "main": "src/main.0" },
    "web": { "kind": "web", "runtime": "wasm32-web", "routes": "src/routes" }
  }
}
```

The `cli` target is required for `zero check` to pass.

## Route Files

Each file in `src/routes/` maps to a URL path:

| File | URL Path |
|---|---|
| `src/routes/index.0` | `/` |
| `src/routes/todos.0` | `/todos` |
| `src/routes/users/profile.0` | `/users/profile` |

Export HTTP method functions:

```zero
pub fun GET(req: Request) -> Response {
    return Response.text("hello from zero")
}

pub fun POST(req: Request) -> Response {
    return Response.json("""{"created":true}""")
}
```

## Request Surface

Available fields on `Request`:
- `method` — HTTP method string
- `url` — full URL
- `headers` — request headers
- `cookies` — cookies
- `params` — route/path parameters
- `body` — request body as string

## Response Builders

| Builder | Use case |
|---|---|
| `Response.text(body)` | Plain text |
| `Response.json(body)` | JSON (pass serialized string) |
| `Response.html(body)` | HTML |
| `Response.redirect(url)` | Redirect |
| `Response.status(code)` | Set status code |

The `body` parameter for `Response.json()` should be a serialized JSON string. Use `std.json` to build and serialize.

## Building JSON Responses

```zero
use std.json

pub fun GET(req: Request) -> Response {
    let root = std.json.object()
    std.json.putString(root, "message", "hello")
    std.json.putBool(root, "ok", true)

    let items = std.json.array()
    let item = std.json.object()
    std.json.putString(item, "id", "1")
    std.json.putString(item, "name", "foo")
    std.json.pushArray(items, item)

    let body = std.json.serialize(root)
    return Response.json(body)
}
```

To read JSON from a request body:

```zero
pub fun POST(req: Request) -> Response {
    let parsed = std.json.parse(req.body)
    // ...
}
```

## Inspect Routes

```sh
zero routes --json .
```

Key JSON fields:
- `routes` — list of `{ method, path, file }` entries
- `routeCount` — total routes
- `measurements.compressedSizeBudgetBytes` — size budget (default 10KB)
- `measurements.frameworkTaxBytes` — always 0
- `webBundle` — target, imports, deployment metadata
- `localRuntime` — command for local dev (`zero dev --target wasm32-web`)

## Route Manifest Example Output

```json
{
  "routes": [
    {"method": "GET", "path": "/", "file": "src/routes/index.0"},
    {"method": "GET", "path": "todos", "file": "src/routes/todos.0"}
  ],
  "routeCount": 2,
  "runtime": "wasm32-web"
}
```

Each route file can export multiple methods. The manifest groups them by file.

## Capability Restrictions

Web WASM bundles have these restrictions:
- **Filesystem**: denied
- **Process**: denied
- **Network**: denied (until Fetch capability)
- **Environment**: preloaded import only
- **DOM**: unavailable to portable worker module

`std.fs`, `std.args`, `std.env.get()`, `std.proc` are unavailable. Use `std.mem`, `std.json`, `std.parse`, `std.codec`, and other target-neutral std modules.

## Deployment

```sh
zero dev --target wasm32-web .     # Local dev server
zero build --emit wasm --target wasm32-web . --out .zero/out/api
```

The bundle is a portable WASM worker with explicit web capabilities. No platform-specific deployment config needed — `providerSpecificDeployment: false`.

## Complete API Example

`zero.json`:
```json
{
  "package": { "name": "todo-api", "version": "0.1.0" },
  "targets": {
    "cli": { "kind": "exe", "main": "src/main.0" },
    "web": { "kind": "web", "runtime": "wasm32-web", "routes": "src/routes" }
  }
}
```

`src/routes/todos.0`:
```zero
use std.json

pub fun GET(req: Request) -> Response {
    let data = std.json.array()
    let item = std.json.object()
    std.json.putString(item, "id", "1")
    std.json.putString(item, "title", "Learn Zero")
    std.json.putBool(item, "done", false)
    std.json.pushArray(data, item)
    let body = std.json.serialize(data)
    return Response.json(body)
}

pub fun POST(req: Request) -> Response {
    let parsed = std.json.parse(req.body)
    let response = std.json.object()
    std.json.putString(response, "message", "created")
    let body = std.json.serialize(response)
    return Response.json(body)
}
```
