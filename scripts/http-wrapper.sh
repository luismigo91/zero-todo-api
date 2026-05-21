#!/bin/sh
read -r method path _
title=$(echo "$path" | sed 's/.*\/todos\///')
[ "$title" = "$path" ] && title=""

action=$(./todo-api "$method" "$path" "$title" 2>/dev/null)
code=$?

case "$action" in
  health)
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n'
    cat /tmp/http-body.json 2>/dev/null || echo '{"message":"todo api running","version":"0.2.0"}'
    ;;
  find)
    sh /app/scripts/mongo-find.sh > /dev/null 2>&1
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n'
    cat /tmp/http-body.json 2>/dev/null || echo '[]'
    ;;
  insert)
    sh /app/scripts/mongo-insert.sh > /dev/null 2>&1
    printf 'HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n'
    cat /tmp/http-body.json 2>/dev/null || echo '{}'
    ;;
  delete)
    sh /app/scripts/mongo-delete.sh > /dev/null 2>&1
    dcode=$?
    if [ "$dcode" = "0" ]; then
      printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n'
    else
      printf 'HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n'
    fi
    cat /tmp/http-body.json 2>/dev/null || echo '{"deleted":true}'
    ;;
  update)
    sh /app/scripts/mongo-update.sh > /dev/null 2>&1
    ucode=$?
    if [ "$ucode" = "0" ]; then
      printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n'
    else
      printf 'HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n'
    fi
    cat /tmp/http-body.json 2>/dev/null || echo '{}'
    ;;
  *)
    case $code in
      1) status="400 Bad Request" ;;
      2) status="404 Not Found" ;;
      *) status="500 Internal Server Error" ;;
    esac
    printf 'HTTP/1.1 %s\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n' "$status"
    cat /tmp/http-body.json 2>/dev/null || echo '{"error":"internal error"}'
    ;;
esac
