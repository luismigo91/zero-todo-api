## MODIFIED Requirements

### Requirement: Architecture Constraints

The Todo API is a native CLI-based application written in Zero (v0.1.2). It compiles for `linux-musl-x64` and uses hosted capabilities (filesystem, process, environment). An HTTP proxy layer handles web routing via temp-file IPC.

- Runtime: `linux-musl-x64` native binary (filesystem access, subprocess spawning, environment variables)
- Responses built with `std.json.object()`, `std.json.putString()`, `std.json.putBool()`, `std.json.serialize()`
- Requests received via temp-file IPC from the HTTP proxy: `--request <path> --response <path>`
- MongoDB accessed through Data API REST endpoints via `std.proc.spawn("curl ...")`
- The CLI target in `zero.json` serves as the application entry point
- Dockerized deployment with multi-stage build on Alpine

### Requirement: List Todos

The system SHALL expose `GET /todos` returning a JSON array of todo items retrieved from MongoDB.

#### Scenario: List returns stored todos
- **WHEN** `GET /todos` is requested
- **THEN** the response SHALL be a JSON array of objects
- **AND** each object SHALL contain `id` (string), `title` (string), and `done` (boolean)
- **AND** the array reflects documents currently stored in MongoDB

#### Scenario: List returns empty array when no todos exist
- **WHEN** `GET /todos` is requested and no documents exist in MongoDB
- **THEN** the response SHALL be an empty JSON array `[]`

### Requirement: Create Todo

The system SHALL expose `POST /todos` accepting a JSON body, persisting the todo to MongoDB, and returning the created todo with its assigned id.

#### Scenario: Create todo persists to database
- **WHEN** `POST /todos` is requested with a JSON body containing a `title` field
- **THEN** the todo is inserted into MongoDB
- **AND** the response SHALL be JSON containing the created todo with `id`, `title`, and `done` fields
- **AND** the response status SHALL be 201

#### Scenario: Create todo with missing title
- **WHEN** `POST /todos` is requested without a `title` field
- **THEN** the response status SHALL be 400
- **AND** the response SHALL contain an error message

## ADDED Requirements

### Requirement: Delete Todo

The system SHALL expose `DELETE /todos/:id` removing a todo from MongoDB by its id.

#### Scenario: Delete existing todo
- **WHEN** `DELETE /todos/:id` is requested with a valid existing id
- **THEN** the todo is removed from MongoDB
- **AND** the response SHALL be `{"deleted":true}` with status 200

#### Scenario: Delete non-existent todo
- **WHEN** `DELETE /todos/:id` is requested with an id that does not exist
- **THEN** the response status SHALL be 404
- **AND** the response SHALL contain an error message

### Requirement: Update Todo

The system SHALL expose `PATCH /todos/:id` accepting a partial JSON body and updating the corresponding todo in MongoDB.

#### Scenario: Update todo title and status
- **WHEN** `PATCH /todos/:id` is requested with `{"title":"New Title","done":true}`
- **THEN** the todo in MongoDB is updated with the new values
- **AND** the response SHALL be the updated todo with status 200

#### Scenario: Partial update preserves other fields
- **WHEN** `PATCH /todos/:id` is requested with only `{"done":true}`
- **THEN** only the `done` field is updated; `title` retains its existing value
- **AND** the response SHALL be the updated todo with status 200

#### Scenario: Update non-existent todo
- **WHEN** `PATCH /todos/:id` is requested with an id that does not exist
- **THEN** the response status SHALL be 404
