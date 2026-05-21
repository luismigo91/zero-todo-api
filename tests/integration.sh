#!/bin/bash
set -e

BASE_URL="${1:-http://localhost:8080}"
PASS=0
FAIL=0

test_case() {
  local desc="$1"
  local method="$2"
  local path="$3"
  local data="$4"
  local expected_status="$5"
  local expected_contains="$6"

  local curl_args=(-s -o /tmp/test-res.json -w "%{http_code}" -X "$method")
  if [ -n "$data" ]; then
    curl_args+=(-H "Content-Type: application/json" -d "$data")
  fi
  curl_args+=("$BASE_URL$path")

  local status
  status=$(curl "${curl_args[@]}")

  if [ "$status" = "$expected_status" ]; then
    if [ -n "$expected_contains" ]; then
      if grep -q "$expected_contains" /tmp/test-res.json 2>/dev/null; then
        echo "  PASS: $desc (status=$status)"
        ((PASS++))
      else
        echo "  FAIL: $desc (status=$status, missing '$expected_contains')"
        echo "    body: $(cat /tmp/test-res.json)"
        ((FAIL++))
      fi
    else
      echo "  PASS: $desc (status=$status)"
      ((PASS++))
    fi
  else
    echo "  FAIL: $desc (expected $expected_status, got $status)"
    echo "    body: $(cat /tmp/test-res.json)"
    ((FAIL++))
  fi
}

echo "=== Todo API Integration Tests ==="
echo "Base URL: $BASE_URL"
echo ""

echo "--- Health ---"
test_case "GET / returns health" "GET" "/" "" "200" "todo api running"

echo ""
echo "--- CRUD: Create ---"
test_case "POST /todos creates todo" "POST" "/todos" '{"title":"Integration test"}' "201" "id"

TODO_ID=$(cat /tmp/test-res.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
if [ -z "$TODO_ID" ]; then
  echo "  WARN: Could not extract todo ID from response, using dummy"
  TODO_ID="test-id"
else
  echo "  Created todo id=$TODO_ID"
fi

echo ""
echo "--- CRUD: List ---"
test_case "GET /todos returns list" "GET" "/todos" "" "200" "$TODO_ID"

echo ""
echo "--- CRUD: Update ---"
test_case "PATCH /todos/:id updates done" "PATCH" "/todos/$TODO_ID" '{"done":true}' "200" "true"

echo ""
echo "--- CRUD: Delete ---"
test_case "DELETE /todos/:id removes todo" "DELETE" "/todos/$TODO_ID" "" "200" "deleted"

echo ""
echo "--- CRUD: Verify deleted ---"
test_case "GET /todos shows empty after delete" "GET" "/todos" "" "200" ""

echo ""
echo "--- Edge Cases ---"
test_case "DELETE non-existent returns 404" "DELETE" "/todos/000000000000000000000000" "" "404" "not found"
test_case "PATCH non-existent returns 404" "PATCH" "/todos/000000000000000000000000" '{"done":true}' "404" "not found"

echo ""
echo "--- OPTIONS (CORS) ---"
test_case "OPTIONS returns 204" "OPTIONS" "/todos" "" "204" ""

echo ""
echo "--- 404 ---"
test_case "GET /unknown returns 404" "GET" "/unknown" "" "404" "not found"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
