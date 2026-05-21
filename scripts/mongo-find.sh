#!/bin/sh
set -e
API_URL="${MONGO_DATA_API_URL:?MONGO_DATA_API_URL not set}"
API_KEY="${MONGO_API_KEY:?MONGO_API_KEY not set}"

BODY=$(jq -n '{dataSource:"todo-cluster", database:"todo", collection:"todos", filter:{}}')
curl -s -X POST "${API_URL}/action/find" \
  -H "api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY" | jq -c '[.documents[]? | {id: ._id, title, done}]'
