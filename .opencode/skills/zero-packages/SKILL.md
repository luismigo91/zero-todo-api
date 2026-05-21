---
name: zero-packages
description: Create, inspect, and repair Zero packages and manifests. Covers zero.json structure, module imports, dependencies, and package graph inspection.
---

# Zero Packages

## Create

```sh
zero new cli hello
zero new lib math-tools
zero new package app
```

## Manifest (zero.json)

Minimal CLI package:
```json
{
  "package": { "name": "hello", "version": "0.1.0" },
  "targets": { "cli": { "kind": "exe", "main": "src/main.0" } }
}
```

Web API package:
```json
{
  "package": { "name": "todo-api", "version": "0.1.0" },
  "targets": {
    "cli": { "kind": "exe", "main": "src/main.0" },
    "web": { "kind": "web", "runtime": "wasm32-web", "routes": "src/routes" }
  }
}
```

- `zero check` on a package requires `targets.cli.main`. Web-only projects still need a CLI target for `check` to pass.
- Pass either the package directory or manifest path: `zero check .` or `zero check zero.json`.

## Module Imports

Package-local imports resolve from `src/`:
- `use helpers` → `src/helpers.0`
- `use config.parser` → `src/config/parser.0` or `src/config/parser/mod.0`

Standard library:
```zero
use std.mem
use std.json
use std.parse
```

## Dependencies

```json
{
  "dependencies": {
    "local-tools": { "path": "../local-tools", "version": "0.1.0" }
  }
}
```

- Local deps must point at a directory with `zero.json`.
- Resolver writes deterministic lock facts under `.zero/package-locks/`.
- No published registry or remote fetch in current compiler.

## Inspect

```sh
zero graph --json <package>
zero doc --json <package>
zero dev --json --trace <package>
```

Graph JSON includes: modules, source paths, import edges, public/private symbols, function effects, required capabilities, target facts.

## Common Repairs

| Code | Fix |
|---|---|
| `IMP001` | Create the imported module at the expected path or fix the `use` spelling. |
| `IMP002` | Break the direct import cycle. |
| `PKG001` | Fix local dependency path so it contains `zero.json`. |
| `PAR100` | Add `"cli": { "kind": "exe", "main": "src/main.0" }` to `targets`. |

## Package Structure Convention

```
package-name/
  zero.json
  src/
    main.0          # CLI entry point
    routes/         # Web route handlers
      index.0
      items.0
    types.0         # Shared types
    helpers.0       # Shared functions
```

- Source files use `.0` extension.
- Route handler files export HTTP method functions (GET, POST, etc.).
- Each route file maps to a URL path derived from the filename.
