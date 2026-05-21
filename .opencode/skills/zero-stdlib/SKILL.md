---
name: zero-stdlib
description: Zero standard library reference. Covers std.mem, std.codec, std.parse, std.json, std.fs, std.args, std.env, std.time, std.rand, std.crypto, and target-gated capabilities.
---

# Zero Standard Library

## Import

```zero
use std.mem
use std.codec
use std.json
```

Call with module path: `std.mem.len(value)`, `std.json.serialize(obj)`.

## Target-Neutral Helpers

### std.mem
- `std.mem.span(stringOrArray)` — create `Span<T>` from literal or array.
- `std.mem.len(value)` — generic length for arrays, spans, strings.
- `std.mem.copy(dest: MutSpan<u8>, src: Span<u8>)` — byte copy.
- `std.mem.fill(dest: MutSpan<u8>, value: u8)` — byte fill.
- `std.mem.eqlBytes(a, b)` — span equality comparison.
- `std.mem.get(value, index) -> Maybe<T>` — safe indexed access.

### std.codec
- `std.codec.readU32(bytes)` — read u32 from bytes.
- `std.codec.encodedVarintLen(value) -> usize` — varint encoding length.
- `std.codec.crc32(data) -> u32` — CRC-32 checksum.

### std.parse
- `std.parse.isAsciiDigit(s) -> Bool`
- `std.parse.isIdentifierStart(s) -> Bool`
- `std.parse.scanDigits(s) -> Maybe<usize>` — parse decimal digits.

### std.json
- `std.json.object() -> JsonObject`
- `std.json.array() -> JsonArray`
- `std.json.putString(obj, key, value)`
- `std.json.putBool(obj, key, value)`
- `std.json.putNumber(obj, key, value)`
- `std.json.pushArray(array, value)`
- `std.json.serialize(value) -> String` — serialize to JSON string.
- `std.json.parse(input) -> JsonValue` — parse JSON string.

### std.time
- `std.time.ms(n)` / `std.time.seconds(n)` — duration constructors.
- `std.time.add(a, b)` — add durations.
- `std.time.asMsFloor(duration) -> i64` — convert to milliseconds.

### std.path
- `std.path.basename(path) -> String`
- `std.path.join(buffer, left, right) -> Maybe<String>`

## Hosted Capabilities (Target-Gated)

These require a host target. Non-host targets reject them with `TAR002`.

### std.args
- `std.args.len() -> usize`
- `std.args.get(index) -> Maybe<String>` — returns `Maybe<String>`.

### std.env
- `std.env.get(name) -> Maybe<String>`

### std.fs
- `std.fs.host() -> Fs` — get host filesystem capability.
- `std.fs.createOrRaise(fs, path) -> owned<File>`
- `std.fs.writeAllOrRaise(file, span) -> usize`
- `std.fs.readAll(alloc, fs, path, maxSize) -> Maybe<Span<u8>>`
- `std.fs.readAllOrRaise(alloc, fs, path, maxSize) -> Span<u8>`
- `std.fs.close(&mut file)` — explicit close (also happens on drop).

### World
- `world.out.write(message) -> usize` — write to stdout.
- `world.err.write(message) -> usize` — write to stderr.

## Memory Pattern

```zero
use std.mem

pub fun main(world: World) -> Void raises {
    let bytes: Span<u8> = std.mem.span("zero")
    if std.mem.len(bytes) == 4 {
        check world.out.write("memory ok\n")
    }
}
```

## Maybe Pattern

```zero
let first = std.args.get(1)
if first.has {
    check world.out.write(first.value)
}
```

- Use `check maybeValue` only when absence should propagate as failure.
- Otherwise inspect `.has` before accessing `.value`.

## Resource Pattern (Filesystem)

```zero
let fs = std.fs.host()
let mut file: owned<File> = check std.fs.createOrRaise(fs, ".zero/out/log.txt")
check std.fs.writeAllOrRaise(&mut file, std.mem.span("hello\n"))
```

- `owned<File>` closes deterministically on lexical scope exit.
- No hidden heap, global logger, or ambient filesystem access.
