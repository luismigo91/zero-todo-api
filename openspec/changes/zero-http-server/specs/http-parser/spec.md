## ADDED Requirements

### Requirement: Read HTTP request from stdin
The system SHALL read raw HTTP request bytes from `/dev/stdin` using `std.fs.read` into a fixed buffer.

#### Scenario: Request is read into buffer
- **WHEN** a TCP connection sends an HTTP request via socat
- **THEN** the Zero process reads the request bytes from `/dev/stdin`
- **AND** the byte count is greater than zero

#### Scenario: Empty stdin
- **WHEN** stdin has no data
- **THEN** the system writes `HTTP/1.1 400 Bad Request` to stdout and exits

### Requirement: Parse HTTP method and path
The system SHALL extract the HTTP method and request path from the first line of the HTTP request by scanning for space characters.

#### Scenario: GET request parsed
- **WHEN** the request starts with `GET /todos HTTP/1.1\r\n`
- **THEN** the method is extracted as `GET` and the path as `/todos`

#### Scenario: POST request with body parsed
- **WHEN** the request starts with `POST /todos HTTP/1.1\r\n`
- **THEN** the method is extracted as `POST` and the path as `/todos`

#### Scenario: Malformed request line
- **WHEN** the first line does not contain two spaces
- **THEN** the system writes `HTTP/1.1 400 Bad Request` to stdout and exits

### Requirement: Parse HTTP request body
The system SHALL extract the request body as bytes following the `\r\n\r\n` separator after headers.

#### Scenario: Body extracted after headers
- **WHEN** the request contains headers followed by `\r\n\r\n` and a JSON body
- **THEN** the body bytes are extracted and written to `/tmp/req-body.json` for POST/PATCH requests

#### Scenario: No body in request
- **WHEN** the request has no body (e.g., GET or DELETE without Content-Length)
- **THEN** an empty body is used

### Requirement: Write HTTP response to stdout
The system SHALL write a valid HTTP/1.1 response to `world.out` including status line, headers, and body.

#### Scenario: 200 response with JSON body
- **WHEN** a request is processed successfully
- **THEN** the system writes `HTTP/1.1 200 OK\r\n` followed by headers, `\r\n`, and the JSON body from `/tmp/http-body.json`

#### Scenario: 404 response
- **WHEN** no route matches the request
- **THEN** the system writes `HTTP/1.1 404 Not Found\r\n` with CORS and content-type headers

#### Scenario: 400 response
- **WHEN** the request is malformed
- **THEN** the system writes `HTTP/1.1 400 Bad Request\r\n`

### Requirement: CORS and Content-Type headers
The system SHALL include CORS and Content-Type headers in every HTTP response.

#### Scenario: CORS headers in response
- **WHEN** any HTTP response is written
- **THEN** the response includes `Access-Control-Allow-Origin: *` and `Content-Type: application/json`

#### Scenario: OPTIONS preflight
- **WHEN** the request method is OPTIONS
- **THEN** the system writes `HTTP/1.1 204 No Content\r\n` with CORS headers and no body

### Requirement: Request size limit
The system SHALL reject requests larger than the fixed stdin buffer (4096 bytes) with a 413 status.

#### Scenario: Oversized request
- **WHEN** the stdin data exceeds the buffer capacity
- **THEN** the system writes `HTTP/1.1 413 Payload Too Large` and exits
