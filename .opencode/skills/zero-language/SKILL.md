---
name: zero-language
description: Compact Zero syntax and semantics guide. Covers types, functions, shapes, enums, choices, match, borrows, references, generics, errors, defer, and import. Use when writing or reviewing .0 source files.
---

# Zero Language

Zero favors explicit capabilities, explicit errors, and small syntax. This reference covers the v0.1.2 compiler surface.

## Minimal Program

```zero
pub fun main(world: World) -> Void raises {
    check world.out.write("hello from zero\n")
}
```

- `pub fun` exports a function. `World` carries runtime capabilities.
- `raises` marks a fallible function.
- `check` calls a fallible operation and propagates failure.

## Primitive Types

```
Bool Void String char
i8 i16 i32 i64 isize
u8 u16 u32 u64 usize
f32 f64
```

- Integer literals are range-checked. Suffixes: `_u8`, `_usize`, `_u32`, etc.
- Untyped float literals default to `f64`. Use `f32` context for `f32`.
- Use `as` for explicit integer/float casts. No implicit narrowing/widening.
- `char` is a byte-sized primitive (`'A'`, `'\n'`, `'\x41'`). Not an integer.
- Conditions must be `Bool`. No truthy integers or strings.

## Bindings and Mutation

```zero
let message = "hello\n"
let mut index = 0
index = index + 1
```

- `let` for immutable. `let mut` for reassignable.
- Fields on mutable shapes are assignable: `point.x = 3`.
- Fixed arrays through `let mut`: `bytes[1] = 90`.
- `MutSpan<T>` writable views support indexed assignment.

## Control Flow

```zero
if value == 42 {
    // branch
} else {
    // alternate
}

while keepGoing {
    // loop
}

for index in 0..4 {
    if index == 2 { continue }
    // body
}
```

- Range `for` loops: end bound is exclusive. Use `break` and `continue`.
- `return` exits a function with a value.

## Functions

```zero
fun answer() -> i32 {
    return 40 + 2
}

pub fun main(world: World) -> Void raises {
    let value = answer()
    check world.out.write("done\n")
}
```

- Signatures: `name: Type`. Return types are explicit.
- Fallible functions must declare `raises` or `raises { ErrorA, ErrorB }`.

## Generics

```zero
fun identity<T>(value: T) -> T {
    return value
}

shape FixedVec<T, static N: usize> {
    len: usize,
    items: [N]T,
}

fun first<T, static N: usize>(vec: ref<FixedVec<T,N>>) -> T {
    return vec.items[0]
}
```

- Type parameters: `<T>`. Static value params: `static N: usize`.
- Calls: `identity<u8>(7_u8)` or `first<u8, 4>(&vec)`.
- Inference works locally: `identity(7_u8)` resolves to `identity<u8>`.

## Shapes, Enums, Choices

```zero
shape Point {
    x: i32,
    y: i32,
}

shape Counter {
    value: i32 = 0,
}

enum Status { ready, failed }

choice Result {
    ok: i32,
    err: String,
}
```

- Construct: `Point { x: 1, y: 2 }`, `Counter {}`, `Result.ok(42)`.
- Field defaults let literals omit fields. Defaults are typechecked.
- Generic shapes: `shape Pair<T, U> { left: T, right: U }`.

### Shape Methods

```zero
shape Counter {
    value: i32,
    fun add(self: ref<Self>, amount: i32) -> i32 {
        return self.value + amount
    }
}

let counter: Counter = Counter { value: 40 }
let answer = Counter.add(&counter, 2)
let answer2 = counter.add(2)
```

- Both namespace style (`Counter.add(&counter, 2)`) and receiver style (`counter.add(2)`) work.
- `Self` inside a generic shape inherits type and static parameters.
- Methods lower to direct function calls. No vtable, no dispatch.

## Match

```zero
match result {
    .ok => value {
        if value == 42 { }
    }
    .err => message {
        // handle error
    }
}
```

- Match must be exhaustive. Use `._` as fallback arm for remaining cases.
- `._` cannot bind payloads.

## Errors

```zero
fun validate(ok: Bool) -> i32 raises { InvalidInput } {
    if ok == false { raise InvalidInput }
    return 42
}

fun run() -> Void raises { InvalidInput } {
    let value = check validate(true)
}
```

- `raises { ... }` restricts the error set.
- A plain `raises` marker is open.
- `check` on fallible functions, `Maybe<T>`, or named-error helpers.
- `rescue` provides local fallback: `let value = expr rescue err { fallback }`.

## Borrows and Memory Views

| Type | Meaning |
|---|---|
| `ref<T>` | Read-only borrow, via `&value` |
| `mutref<T>` | Mutable borrow, via `&mut value` |
| `[N]T` | Fixed array |
| `Span<T>` | Read-only contiguous view |
| `MutSpan<T>` | Writable contiguous view |
| `Maybe<T>` | Optional value (`.has`, `.value`) |
| `owned<T>` | Explicit resource ownership |

```zero
fun bump(point: mutref<Point>) -> Void {
    point.x = point.x + 1
}
```

## Indexing and Slicing

```zero
let bytes: [4]u8 = [65, 66, 67, 68]
let first: u8 = bytes[0]
let tail: Span<u8> = bytes[1..4]

let text: String = "zero"
let byte: u8 = text[1]
let slice: Span<u8> = text[1..]
```

- Indexing: `[N]T`, `Span<T>`, `MutSpan<T>` return `T`. `String` returns `u8`.
- Slices are half-open: `start..end`, `start..`, `..end`, `..`.
- Bounds traps on out-of-range access. Use `std.mem.get(value, index)` for `Maybe<T>`.

## Defer and Owned

```zero
pub fun main(world: World) -> Void raises {
    defer cleanup()
    check world.out.write("work\n")
}
```

- `defer` schedules cleanup at scope exit (return, break, continue).
- Live `owned<T>` locals clean up automatically via canonical `drop(self: mutref<Self>)`.
- `owned<File>` closes deterministically. Direct `value.drop()` is rejected.
- No registry, refcount, or global cleanup.

## Imports

```zero
use std.mem
use std.codec
use std.json
use helpers
use config.parser
```

- Std imports: `use std.mem`, `use std.parse`, etc.
- Package-local: `use helpers` resolves `src/helpers.0`.
- Nested: `use config.parser` resolves `src/config/parser.0` or `src/config/parser/mod.0`.

## What NOT to do

- Do not invent syntax that isn't in this reference or `zero check --json`.
- Do not use hidden globals, ambient I/O, or implicit allocation.
- Do not use truthy integers/strings as conditions.
- Do not call `value.drop()` directly.
