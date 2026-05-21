#!/bin/sh
set -e
API_URL="${MONGO_DATA_API_URL:?MONGO_DATA_API_URL not set}"
API_KEY="${MONGO_API_KEY:?MONGO_API_KEY not set}"
ID=$(cat /tmp/todo-id.txt)

BODY=$(jq -n --arg id "$ID" \
  '{dataSource:"todo-cluster", database:"todo", collection:"todos", filter:{_id:{$oid:$id}}}')
RESULT=$(curl -s -X POST "${API_URL}/action/deleteOne" \
  -H "api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY")
DELETED=$(echo "$RESULT" | jq -r '.deletedCount // 0')
if [ "$DELETED" != "0" ]; then
  echo '{"deleted":true}'
else
  echo '{"error":"not found"}' >&2
  exit 2
fi
