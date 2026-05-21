## ADDED Requirements

### Requirement: Database connection configuration
The system SHALL read `MONGO_DATA_API_URL` and `MONGO_API_KEY` from environment variables via `std.env.get`.

#### Scenario: Environment variables present
- **WHEN** both `MONGO_DATA_API_URL` and `MONGO_API_KEY` are set
- **THEN** the system uses them to construct Data API requests

#### Scenario: Missing environment variables
- **WHEN** either `MONGO_DATA_API_URL` or `MONGO_API_KEY` is not set
- **THEN** the system returns an error indicating missing configuration

### Requirement: List todos from MongoDB
The system SHALL retrieve all todo documents from MongoDB via `POST /action/find` on the Data API endpoint.

#### Scenario: List returns stored todos
- **WHEN** the system queries MongoDB with an empty filter
- **THEN** the system returns a JSON array of todo objects, each containing `id` (string), `title` (string), and `done` (boolean)
- **AND** the JSON array matches documents stored in the `todos` collection

#### Scenario: Empty collection
- **WHEN** the `todos` collection has no documents
- **THEN** the system returns an empty JSON array `[]`

### Requirement: Create todo in MongoDB
The system SHALL insert a new todo document via `POST /action/insertOne` on the Data API endpoint.

#### Scenario: Create todo persists to MongoDB
- **WHEN** a todo is created with `{"title":"Learn Zero","done":false}`
- **THEN** the system inserts a document with an auto-generated `_id` in the `todos` collection
- **AND** the system returns the created todo with its `id` field

#### Scenario: Create todo with missing title
- **WHEN** a create request body has no `title` field
- **THEN** the system returns a 400 error

### Requirement: Delete todo from MongoDB
The system SHALL delete a todo document by its `_id` via `POST /action/deleteOne` on the Data API endpoint.

#### Scenario: Delete existing todo
- **WHEN** the system deletes a todo with a valid MongoDB ObjectId
- **THEN** the document is removed from the `todos` collection
- **AND** the system returns `{"deleted":true}`

#### Scenario: Delete non-existent todo
- **WHEN** the system deletes a todo with an id that does not exist
- **THEN** the system returns `{"deleted":false,"error":"not found"}` with status 404

### Requirement: Update todo in MongoDB
The system SHALL update a todo document via `POST /action/updateOne` on the Data API endpoint.

#### Scenario: Update todo title and done status
- **WHEN** the system updates a todo with `{"title":"Updated Title","done":true}`
- **THEN** the document in MongoDB is updated with the new values
- **AND** the system returns the updated todo

#### Scenario: Partial update of todo
- **WHEN** the system updates a todo with only `{"done":true}`
- **THEN** only the `done` field is updated; the `title` retains its existing value

### Requirement: MongoDB error handling
The system SHALL handle MongoDB Data API errors gracefully.

#### Scenario: Data API returns an error
- **WHEN** the Data API returns a non-200 status or an error in the response body
- **THEN** the system returns a 500 error with details from the MongoDB response

#### Scenario: curl spawn fails
- **WHEN** the `curl` subprocess exits with a non-zero code
- **THEN** the system returns a 500 error indicating the database request failed
