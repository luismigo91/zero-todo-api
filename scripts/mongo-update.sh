#!/bin/sh
set -e
API_URL="${MONGO_DATA_API_URL:?MONGO_DATA_API_URL not set}"
API_KEY="${MONGO_API_KEY:?MONGO_API_KEY not set}"
ID=$(cat /tmp/todo-id.txt)
TITLE=$(jq -r '.title // ""' /tmp/req-body.json)
DONE=$(jq -r '.done // ""' /tmp/req-body.json)

BODY=$(jq -n \
  --arg id "$ID" \
  --arg title "$TITLE" \
  --arg done "$DONE" \
  '{
    dataSource: "todo-cluster",
    database: "todo",
    collection: "todos",
    filter: {_id: {$oid: $id}},
    update: {$set: {title: $title, done: ($done == "true")}}
  }')
RESULT=$(curl -s -X POST "${API_URL}/action/updateOne" \
  -H "api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY")
MATCHED=$(echo "$RESULT" | jq -r '.matchedCount // 0')
if [ "$MATCHED" != "0" ]; then
  FIND_BODY=$(jq -n --arg id "$ID" \
    '{dataSource:"todo-cluster", database:"todo", collection:"todos", filter:{_id:{$oid:$id}}, limit:1}')
  curl -s -X POST "${API_URL}/action/find" \
    -H "api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$FIND_BODY" | jq -c '.documents[0] | {id: ._id, title, done}'
else
  echo '{"error":"not found"}' >&2
  exit 2
fi
