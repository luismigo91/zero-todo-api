---
name: zero-diagnostics
description: Read Zero diagnostics, explanations, and fix plans. Zero diagnostics are designed for agents — consume JSON first, then prose.
---

# Zero Diagnostics

## Commands

```sh
zero check --json <input>
zero explain <diagnostic-code>
zero explain --json <diagnostic-code>
zero fix --plan --json <input>
```

`zero fix` is plan-only. It reports candidate repairs but does not edit files.

## Diagnostic JSON Shape

Fields from `zero check --json`:

| Field | Meaning |
|---|---|
| `code` | Stable code like `NAM003`, `TAR002` |
| `message` | Short human summary |
| `path`, `line`, `column`, `length` | Source span |
| `expected` / `actual` | Structured mismatch facts |
| `help` | Concise next action |
| `fixSafety` | Safety label for agent repair |
| `repair` | Optional repair id and summary |
| `related` | Extra spans or facts |

## Fix Safety Levels

From `zero fix --plan --json`:

| Safety Level | Meaning |
|---|---|
| `format-only` | Formatting/trivia only |
| `behavior-preserving` | Intended not to change runtime |
| `api-changing` | Signatures/exports/call sites may change |
| `target-changing` | Target support may change |
| `requires-human-review` | Compiler cannot prove edit is safe |

Apply only what you can justify. Treat `requires-human-review` as a planning hint.

## Common Diagnostic Codes

| Code | Meaning |
|---|---|
| `NAM003` | Unknown name. Declare it, import it, or fix spelling. |
| `IMP001` | Unknown package-local import. |
| `IMP002` | Package-local import cycle. |
| `APP001` | Missing `main` function when checking a standalone file. |
| `PKG001` | Local dependency path lacks `zero.json`. |
| `PKG002` | Package dependency cycle. |
| `PKG003` | One package name resolves to conflicting versions. |
| `PKG004` | Selected target not supported by a dependency. |
| `PAR100` | Missing `targets.cli.main` in `zero.json`. |
| `TAR001` | Unknown target. Run `zero targets`. |
| `TAR002` | Capability unavailable for selected target. |
| `BLD003` | Removed backend flag. Use direct emitters. |
| `MET001` | Unsupported compile-time expression. |
| `STC001` | Unsupported static parameter type. |
| `STC002` | Runtime value where compile-time value required. |
| `STC003` | Static argument does not match expected value. |
| `SHM001` | Generic shape method call cannot bind `Self`, `T`, or `N`. |
| `SHM002` | Explicit method arguments and receiver shape disagree. |
| `RCV001` | Unknown or non-receiver method. |
| `RCV002` | Temporary/immutable receiver where mutable required. |
| `IFC001-IFC005` | Static interface constraint violations. |

## Agent Triage

1. Run failing command with `--json` when supported.
2. Use the span to inspect only the relevant source first.
3. Run `zero explain <code>` before broad refactors.
4. If multiple diagnostics share a root cause, fix the earliest issue.
5. Re-run the same command after patching.
