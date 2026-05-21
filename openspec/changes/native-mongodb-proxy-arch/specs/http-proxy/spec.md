## ADDED Requirements

### Requirement: Proxy forwards HTTP requests to Zero CLI
The Node.js proxy SHALL receive incoming HTTP requests, serialize them to a JSON request file, spawn the Zero CLI binary, read the JSON response file, and return the response to the client.

#### Scenario: GET /todos forwarded successfully
- **WHEN** the proxy receives `GET /todos`
- **THEN** it writes `{"method":"GET","path":"/todos","body":null}` to a temp request file
- **AND** spawns the Zero CLI with `--request` and `--response` arguments
- **AND** reads the response file and returns its `status` and `body` as the HTTP response

#### Scenario: POST /todos with body forwarded
- **WHEN** the proxy receives `POST /todos` with JSON body `{"title":"New Task"}`
- **THEN** the request file contains the body as a JSON string

#### Scenario: Zero CLI exits with error
- **WHEN** the Zero CLI process exits with a non-zero exit code
- **THEN** the proxy returns HTTP 500 with an error message

### Requirement: Proxy handles CORS
The proxy SHALL set CORS headers allowing all origins for development use.

#### Scenario: Preflight OPTIONS request
- **WHEN** the proxy receives an `OPTIONS` request with `Origin` and `Access-Control-Request-Method` headers
- **THEN** the proxy returns 204 with `Access-Control-Allow-Origin: *` and allowed methods

#### Scenario: Regular request includes CORS headers
- **WHEN** the proxy processes any request
- **THEN** the response includes `Access-Control-Allow-Origin: *`

### Requirement: Proxy sets Content-Type header
The proxy SHALL set `Content-Type: application/json` on all API responses.

#### Scenario: JSON content type in response
- **WHEN** the proxy returns any API response
- **THEN** the response includes the header `Content-Type: application/json`

### Requirement: Temp file cleanup
The proxy SHALL clean up temporary request and response files after each request.

#### Scenario: Files cleaned after successful request
- **WHEN** a request completes successfully
- **THEN** both the request and response temp files are deleted

#### Scenario: Files cleaned after failed request
- **WHEN** a request fails
- **THEN** both the request and response temp files are deleted
