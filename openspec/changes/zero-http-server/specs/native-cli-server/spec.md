## MODIFIED Requirements

### Requirement: CLI reads request from temp file

The Zero process SHALL read the raw HTTP request from `/dev/stdin` instead of reading a JSON request file via `--request <path>`.

#### Scenario: HTTP request read from stdin
- **WHEN** socat pipes a TCP connection to the Zero process
- **THEN** the process reads HTTP bytes from `/dev/stdin` using `std.fs.read`

#### Scenario: HTTP method and path extracted
- **WHEN** HTTP bytes are read from stdin
- **THEN** the HTTP parser extracts method and path from the request line

### Requirement: CLI writes response to temp file

The Zero process SHALL write the HTTP response directly to `world.out` instead of writing a JSON response file at `--response <path>`.

#### Scenario: HTTP response written to stdout
- **WHEN** a request is processed
- **THEN** the HTTP status line, headers, and body are written to `world.out`

### Requirement: CLI dispatches by HTTP method and path

The CLI SHALL receive method and path from the HTTP parser (instead of CLI arguments) and dispatch to the same router. Routing logic is unchanged.

#### Scenario: GET /todos dispatched via HTTP
- **WHEN** the parser extracts method=`GET` and path=`/todos`
- **THEN** the router calls `appListTodos` as before

## REMOVED Requirements

### Requirement: CLI accepts --request and --response arguments
**Reason**: Replaced by stdin/stdout HTTP model with socat bridge.
**Migration**: The CLI no longer takes file path arguments. socat pipes HTTP directly to stdin.
