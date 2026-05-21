---
name: zero-agent
description: Agent workflow for writing and editing Zero code. Covers the edit-compile-verify loop, JSON-first feedback, capability awareness, and project conventions.
---

# Zero Agent Workflow

## Prerequisites

```sh
zero --version                   # Verify Zero is installed
export PATH="$HOME/.zero/bin:$PATH"
```

Install if missing:
```sh
curl -fsSL https://zerolang.ai/install.sh | bash
```

## The Edit Loop

1. **Read** the nearest `.0` file, `zero.json`, and relevant examples before editing.
2. **Make the smallest change** that satisfies the request.
3. **Check** with JSON:
   ```sh
   zero check --json <file-or-package>
   ```
4. **Diagnose** errors before blindly tweaking:
   ```sh
   zero explain <diagnostic-code>
   zero fix --plan --json <file-or-package>
   ```
5. **Validate** with the narrowest command:
   - `zero check .` for syntax/types
   - `zero test --json .` for behavior
   - `zero routes --json .` for web routes
   - `zero build <target>` for cross-builds

## Core Rules

- **Effects as capabilities.** Never use hidden globals or ambient I/O. Use `World`, `std.fs`, `std.args`, `std.env` only where the target supports them.
- **Check target surfaces.** A WASM web bundle cannot use `std.fs`. Check `zero routes --json` or `zero graph --json` for capability restrictions.
- **Prefer explicit types** at public boundaries and when inference is unclear.
- **Use `Maybe<T>`, `raises`, and `check`** instead of hidden failure models.
- **Do not invent syntax.** Load `zero-language` skill when unsure. Run `zero check --json` if a syntax idea might work.
- **Do not invent CLI fields.** Run the command with `--json` and read actual data.
- **Explicit allocator for allocation.** No implicit heap. Use `NullAlloc` or fixed-buffer allocation.

## Package Check Convention

A Zero package must have a `cli` target in `zero.json` for `zero check` to pass:

```json
{
  "targets": {
    "cli": { "kind": "exe", "main": "src/main.0" },
    "web": { "kind": "web", "runtime": "wasm32-web", "routes": "src/routes" }
  }
}
```

Even web-only projects need a dummy `src/main.0` with `pub fun main(world: World) -> Void raises { }`.

## Project Structure

```
project/
  zero.json           # Package manifest (required)
  src/
    main.0            # CLI entry (required for zero check)
    routes/           # Web route handlers
      index.0         # GET /
      items.0         # GET /items, POST /items
    types.0           # Shared types
    helpers.0         # Shared functions
  .zero/              # Build artifacts (gitignore)
```

## Web Route Handlers

Route files export HTTP method functions:

```zero
use std.json

pub fun GET(req: Request) -> Response {
    return Response.text("hello")
}

pub fun POST(req: Request) -> Response {
    return Response.json("{\"ok\":true}")
}
```

- Route path comes from filename: `src/routes/todos.0` → `/todos`.
- Available request fields: `method`, `url`, `headers`, `cookies`, `params`, `body`.
- Response builders: `Response.text()`, `Response.json()`, `Response.html()`, `Response.redirect()`.
- Response fields: `status`, `headers`, `cookies`, `body`.

## Useful Focused Commands

```sh
zero check --json <input>
zero graph --json <input>
zero test --json <input>
zero size --json <input>
zero doctor --json
zero routes --json <web-package>
```

## Common Pitfalls

- Files checked individually (not as package) require a `pub fun main`. Route files don't need `main` when checked via package.
- `zero.json` needs both `cli` and `web` targets for check + routes to work together.
- `std.json` JSON building API is explicit-buffer. Build objects/arrays with `std.json.object()`, `std.json.putString()`, then serialize.
- Integer types don't implicitly convert. Use `as` for explicit casts.
- `char` is not an integer. Don't use it in arithmetic.
