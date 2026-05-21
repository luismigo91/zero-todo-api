---
name: zero-builds
description: Build, run, ship, target, and profile Zero programs. Covers direct emitters, cross-building, size reports, and target capability gating.
---

# Zero Builds

## Quick Commands

```sh
zero check <file-or-package>
zero run <file-or-package>
zero run <file-or-package> -- program-args
zero test <file-or-package>
zero build --emit exe <file> --out <path>
zero build --emit wasm --target wasm32-web <input>
zero routes --json <web-package>
```

## Run

```sh
zero run examples/hello.0
zero run examples/cli-file.0 -- input.txt
```

Arguments after `--` are passed to the Zero program. The run command uses the host target.

## Build

Use direct emitters only. The generated-C backend was removed.

```sh
zero build --emit exe examples/add.0 --out .zero/out/add
zero build --emit obj examples/add.0 --out .zero/out/add.o
zero build --emit wasm --target wasm32-wasi examples/direct-wasm-add.0
zero build --emit wasm --target wasm32-web --out .zero/out/app examples/web/hello
```

Use `--json` for machine-readable output:
```sh
zero build --json --target linux-musl-x64 examples/memory-package
```

## Targets

Available targets: `darwin-arm64`, `darwin-x64`, `linux-musl-x64`, `linux-musl-arm64`, `linux-x64`, `linux-arm64`, `win32-x64.exe`, `win32-arm64.exe`, `wasm32-wasi`, `wasm32-web`.

```sh
zero targets
zero check --target linux-musl-x64 <input>
zero graph --json --target linux-musl-x64 <input>
```

Hosted APIs (`std.fs`, `std.args`, `std.env`, `std.net`, `std.proc`) are target-gated. Non-host targets reject hosted helpers with `TAR002`.

## Profiles

Profiles: `debug`, `dev`, `release-fast`, `release-small`, `tiny`, `audit`.

```sh
zero build --profile release-small examples/hello.0
zero size --json --profile tiny examples/hello.0
```

## Size

```sh
zero size --json examples/hello.0
```

Useful JSON fields: `sizeBreakdown`, `retentionReasons`, `optimizationHints`. Explains retained functions, sections, literals, runtime shims, imports.

## Ship

```sh
zero ship --json --target linux-musl-x64 examples/hello.0 --out .zero/ship/hello
```

Preview includes artifact names, sizes, hashes, checksums, size report, and debug metadata.

## Dev Server

```sh
zero dev --target wasm32-web .
zero dev --json --trace <package>
```

## Troubleshooting

- `zero doctor --json` checks host/target readiness.
- `BLD003` means an old backend flag; remove it and use direct emitters.
- `TAR002` means capability unavailable for selected target.
- Missing sysroot facts identify required `ZERO_SYSROOT_*` variables.
