# Todo API Specification

The Todo API is a WASM-based web API written in Zero (v0.1.2). It runs on the `wasm32-web` target with zero framework tax.

## Requirement: API Health Endpoint

The system SHALL expose a health-check endpoint at `GET /` that returns API metadata.

### Scenario: Health check returns JSON
- GIVEN the API is running
- WHEN `GET /` is requested
- THEN the response SHALL be JSON with fields `message` (string) and `version` (string)
- AND the response status SHALL be 200

## Requirement: List Todos

The system SHALL expose `GET /todos` returning a JSON array of todo items.

### Scenario: List returns pre-seeded todos
- GIVEN the API is running
- WHEN `GET /todos` is requested
- THEN the response SHALL be a JSON array of objects
- AND each object SHALL contain `id` (string), `title` (string), and `done` (boolean)

## Requirement: Create Todo

The system SHALL expose `POST /todos` accepting a JSON body and returning a response.

### Scenario: Create todo returns acknowledgment
- GIVEN the API is running
- WHEN `POST /todos` is requested with a JSON body
- THEN the response SHALL be JSON with a `message` field indicating creation
- AND the response status SHALL be 200

## Architecture Constraints

- Runtime: `wasm32-web` (no filesystem, no process, no ambient environment)
- Responses built with `std.json.object()`, `std.json.putString()`, `std.json.putBool()`, `std.json.serialize()`
- Route files in `src/routes/` map to URL paths via filename
- Each route file exports named functions corresponding to HTTP methods
- The CLI target in `zero.json` is required for `zero check` to pass
- `frameworkTaxBytes: 0` — no JS runtime overhead
