## ADDED Requirements

### Requirement: CLI reads request from temp file
The Zero CLI binary SHALL accept `--request <path>` and `--response <path>` arguments and SHALL read the full request JSON from the specified request file using `std.fs.readAllOrRaise`.

#### Scenario: CLI reads valid request file
- **WHEN** the CLI is invoked with `--request /tmp/req.json --response /tmp/res.json`
- **THEN** the CLI reads and parses `/tmp/req.json` as JSON containing `method`, `path`, and `body` fields

#### Scenario: CLI handles missing request file
- **WHEN** the CLI is invoked with a request path that does not exist
- **THEN** the CLI writes an error JSON response to the response file with status 400 and exits with a non-zero code

### Requirement: CLI writes response to temp file
The Zero CLI binary SHALL write a JSON response to the specified response file path containing `status` (integer) and `body` (JSON string or null).

#### Scenario: Successful response
- **WHEN** a request is processed successfully
- **THEN** the response file contains `{"status":200,"body":"<json string>"}`

#### Scenario: Error response
- **WHEN** a request fails during processing
- **THEN** the response file contains `{"status":<error code>,"body":"{\"error\":\"...\"}"}`

### Requirement: CLI dispatches by HTTP method and path
The CLI SHALL parse the request JSON and route to the appropriate handler based on `method` and `path` fields.

#### Scenario: GET /todos dispatched
- **WHEN** the request contains `{"method":"GET","path":"/todos"}`
- **THEN** the CLI calls the list-todos handler

#### Scenario: POST /todos dispatched
- **WHEN** the request contains `{"method":"POST","path":"/todos","body":"{\"title\":\"...\"}"}`
- **THEN** the CLI calls the create-todo handler with the parsed body

#### Scenario: DELETE /todos/:id dispatched
- **WHEN** the request contains `{"method":"DELETE","path":"/todos/abc123"}`
- **THEN** the CLI extracts the id `abc123` and calls the delete-todo handler

#### Scenario: PATCH /todos/:id dispatched
- **WHEN** the request contains `{"method":"PATCH","path":"/todos/abc123","body":"{\"done\":true}"}`
- **THEN** the CLI extracts the id `abc123` and calls the update-todo handler

#### Scenario: Unknown path
- **WHEN** the request path does not match any known route
- **THEN** the CLI writes a 404 error response

### Requirement: Health check endpoint
The CLI SHALL respond to `GET /` with API metadata.

#### Scenario: Health check returns JSON
- **WHEN** `{"method":"GET","path":"/"}`
- **THEN** the response body contains `{"message":"todo api running","version":"0.2.0"}` with status 200
