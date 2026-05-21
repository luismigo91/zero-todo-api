FROM alpine:latest AS builder

RUN apk add --no-cache curl bash

RUN curl -fsSL https://zerolang.ai/install.sh | bash
ENV PATH="/root/.zero/bin:${PATH}"

WORKDIR /src
COPY zero.json .
COPY src/ src/

RUN zero check . --json
RUN zero build --emit exe . --out /app/todo-api 2>&1 || \
    echo "build failed — binary must be compiled on Linux host"

FROM alpine:latest

RUN apk add --no-cache curl jq bash socat

WORKDIR /app
COPY scripts/ /app/scripts/
COPY --from=builder /app/todo-api /app/todo-api 2>/dev/null || true

RUN chmod +x /app/scripts/*.sh /app/todo-api 2>/dev/null || true

ENV PORT=8080

EXPOSE 8080
CMD ["socat", "TCP-LISTEN:8080,fork,reuseaddr", "EXEC:sh /app/scripts/http-wrapper.sh"]
