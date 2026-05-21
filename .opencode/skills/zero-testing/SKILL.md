---
name: zero-testing
description: Write and run Zero test blocks with JSON output. Covers test blocks, filters, expected failures, and JSON test results.
---

# Zero Testing

## Test Blocks

```zero
fun add(left: i32, right: i32) -> i32 {
    return left + right
}

test "addition works" {
    expect(add(2, 3) == 5)
}
```

- Test blocks live next to source code.
- `expect` requires a `Bool`. False expectations fail the test.

## Run Tests

```sh
zero test <file-or-package>
zero test --json <file-or-package>
zero test --json --filter addition <file-or-package>
```

- `--filter` matches test names by substring.
- Use for quick feedback loops while editing.

## JSON Output

Key fields from `zero test --json`:

| Field | Meaning |
|---|---|
| `discoveredTests` | All tests found |
| `selectedTests` | Tests matching filter |
| `passedTests` | Passing count |
| `failedTests` | Failing count |
| `results` | Per-test: name, status, duration, location, failure span |
| `snapshotKey` | Stable snapshot contract |

## Expected Failures

Mark expected-fail tests with `xfail:` in the name:

```zero
test "xfail: pending parser edge case" {
    expect(false)
}
```

Also accepted: `expected fail:` prefix or `[xfail]` marker.

- Expected-fail tests pass the command only when they fail as expected.
- If they start passing, the command fails with `unexpectedPasses`.
- Remove `xfail` when a bug is fixed.

## Agent Workflow

1. Add the smallest test that owns the behavior.
2. Run `zero test --json --filter <test-name>` while editing.
3. Run the full package test before finishing.
4. Do not leave `xfail` on a fixed bug.
5. Use `zero check --json` first when the failure is a compile error.
