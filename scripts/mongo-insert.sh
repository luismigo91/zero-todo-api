#!/bin/sh
set -e
API_URL="${MONGO_DATA_API_URL:?MONGO_DATA_API_URL not set}"
API_KEY="${MONGO_API_KEY:?MONGO_API_KEY not set}"
TITLE=$(jq -r '.title' /tmp/req-body.json)

BODY=$(jq -n --arg title "$TITLE" \
  '{dataSource:"todo-cluster", database:"todo", collection:"todos", document:{title:$title, done:false}}')
RESULT=$(curl -s -X POST "${API_URL}/action/insertOne" \
  -H "api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY")
echo "$RESULT" | jq -c --arg title "$TITLE" '{id: .insertedId, title: $title, done: false}'
