# Zero — Todo API

API REST de tareas (CRUD) implementada en el lenguaje **Zero v0.1.2**, explorando las capacidades y limitaciones reales del compilador en su estado actual.

---

## Resumen del Proyecto

Este proyecto es un experimento de ingeniería para construir una API HTTP funcional usando exclusivamente Zero. El objetivo es documentar empíricamente qué funciona, qué no, y qué arquitecturas son viables con el compilador v0.1.2.

**Estado actual:** la API compila para `wasm32-web` y sirve datos mock (hardcoded). El backend nativo (`--emit exe`) tiene un subconjunto muy limitado de funcionalidad — no soporta comparaciones de strings, `std.fs`, `std.proc`, ni `std.mem.len()` en contextos de comparación.

---

## Toolchain

```sh
# Instalación del compilador
curl -fsSL https://zerolang.ai/install.sh | bash
export PATH="$HOME/.zero/bin:$PATH"

# Comandos principales
zero check .                     # Verificar el proyecto (0 diagnostics = ok)
zero routes --json .             # Ver rutas web detectadas
zero build --emit wasm --target wasm32-web .  # Compilar a WASM
zero run .                       # Ejecutar el CLI nativo
zero dev --target wasm32-web .   # Dev server (plan-only, no funcional)
```

---

## Estructura del Proyecto

```
zero/
├── zero.json                    # targets: cli (exe) + web (wasm32-web)
├── opencode.json                # Config de OpenCode: AGENTS.md como instructions
├── AGENTS.md                    # Guía para agentes de código
├── README.md                    # Este documento
├── Dockerfile                   # Multi-stage: alpine + socat + Zero binary
├── docker-compose.yml           # api + mongo (MongoDB 7)
├── .gitignore                   # .zero/out/, .zero/cache/, .zero/package-locks/
├── src/
│   ├── main.0                   # CLI entry point (necesario para zero check)
│   └── routes/
│       ├── index.0              # GET /  → health check con metadata
│       └── todos.0              # GET /todos, POST /todos con datos mock
├── scripts/
│   ├── http-wrapper.sh          # Wrapper bash: HTTP parsing + dispatch a Zero
│   ├── mongo-find.sh            # MongoDB Data API: listar todos
│   ├── mongo-insert.sh          # MongoDB Data API: crear todo
│   ├── mongo-delete.sh          # MongoDB Data API: eliminar todo
│   └── mongo-update.sh          # MongoDB Data API: actualizar todo
├── tests/
│   └── integration.sh           # Tests de integración HTTP (curl-based)
├── openspec/
│   ├── specs/                   # Specs base (vacío actualmente)
│   └── changes/
│       ├── native-mongodb-proxy-arch/  # Cambio 1: Zero CLI + proxy Node.js
│       └── zero-http-server/           # Cambio 2: socat + Zero como HTTP server
├── .opencode/
│   └── skills/                  # Skills de OpenCode para el proyecto
└── .zero/                       # Build artifacts (cache, package-locks, out/)
```

---

## Arquitectura Actual (wasm32-web)

### Route Handlers

| Archivo | Método | Ruta | Descripción |
|---------|--------|------|-------------|
| `src/routes/index.0` | `GET` | `/` | Health check: `{"message":"todo api running","version":"0.2.0"}` |
| `src/routes/todos.0` | `GET` | `/todos` | Lista 3 todos hardcoded |
| `src/routes/todos.0` | `POST` | `/todos` | Eco del body recibido (sin persistencia) |

**Flujo de datos:**
```
Cliente HTTP → Route Handler (.0) → std.json.object/putString/serialize → Response.json()
```

**Limitaciones de esta arquitectura:**
- Sin persistencia (datos hardcoded)
- Solo GET y POST implementados
- Sin DELETE ni PATCH
- `zero dev --target wasm32-web` no arranca servidor real (plan-only)
- El WASM generado es `browser-worker` con import WASI `fd_write`, no usable en navegador sin glue code

---

## Capacidades del Compilador — Qué SÍ Funciona

### WASM Target (`wasm32-web`)

| Capacidad | Estado |
|-----------|--------|
| `zero check .` | ✅ 0 diagnostics |
| `zero routes --json .` | ✅ Detecta rutas correctamente |
| `zero build --emit wasm --target wasm32-web .` | ✅ Genera .wasm (160 B) |
| `std.json.*` (object, putString, putBool, pushArray, parse, serialize) | ✅ Funciona en route handlers |
| `Request` / `Response` surfaces | ✅ `Response.json(body)` |
| `frameworkTaxBytes` | ✅ 0 (sin overhead de framework) |

### Native Target (`--emit exe`, `linux-musl-x64` en Docker)

| Capacidad | Estado |
|-----------|--------|
| `world.out.write("texto")` | ✅ |
| `std.args.get(index)` — leer argumentos | ✅ |
| Control flow: `if`/`else`, `while`, `for` (sobre enteros) | ✅ |
| Aritmética de enteros: `+`, `-`, `*`, comparaciones (`==`, `<`, `>`) | ✅ |
| `let`, `let mut`, reasignación de enteros | ✅ |
| Funciones que devuelven `i32`, `Void` | ✅ |
| Hello World (241 B) | ✅ |
| Eco de argumentos (354 B) | ✅ |
| Contador con while loop (332 B) | ✅ |
| `throw`/`catch` | ✅ |

---

## Limitaciones Críticas del Compilador — Qué NO Funciona

### CGEN004 — Code Generation Failure

El backend nativo falla al generar código para estas operaciones. **Este es el bloqueante principal** que impide cualquier implementación seria.

| Operación | Error | Impacto |
|-----------|-------|---------|
| `==` sobre `String` (ej: `method == "GET"`) | CGEN004 | No se puede hacer routing HTTP |
| `==` sobre `Span<u8>` (ej: `path[..7] == "/todos/"[..]`) | CGEN004 | No se puede parsear rutas con parámetros |
| `std.fs.host()` | CGEN004 | No se puede acceder al filesystem |
| `std.fs.read()` | CGEN004 | No se puede leer archivos |
| `std.fs.createOrRaise()` | CGEN004 | No se puede crear archivos |
| `std.fs.writeAllOrRaise()` | CGEN004 | No se puede escribir archivos |
| `std.proc.spawn()` | CGEN004 | No se puede ejecutar subprocesos |
| `std.mem.len()` en contexto de comparación | CGEN004 | No se puede medir longitud de strings y comparar |
| Slicing de strings: `path[..7]` | CGEN004 | No se puede extraer substrings |
| `zero build --emit exe` en `darwin-arm64` | CGEN004 | Backend no implementado para macOS ARM |

### STD — Errores de Biblioteca Estándar

| Operación | Error | Workaround |
|-----------|-------|------------|
| `std.fs.write(path, span)` | STD003 | Usar `createOrRaise` + `writeAllOrRaise` con `owned<File>` (pero CGEN004 bloquea ambas) |
| `std.json` en módulos CLI | STD002 | Solo disponible en web route handlers. En CLI usar strings literales. |

### TYP — Errores de Tipos

| Operación | Error | Regla |
|-----------|-------|-------|
| Comparar `String` con `Span<u8>` | TYP002 | Ambos lados deben ser del mismo tipo |
| `Maybe<T>` con valor directo (no `null`) | TYP003 | No hay auto-wrapping; separar validación (`Bool`) de construcción |

### PAR — Errores de Parsing

| Patrón | Error |
|--------|-------|
| Coma final en shape literal: `{ x: 1, y: 2, }` | PAR100 |

### IMP — Errores de Imports

| Patrón | Error |
|--------|-------|
| Dos `pub fun` con el mismo nombre en distintos módulos | IMP003 |

### TAR — Errores de Target

| Patrón | Error |
|--------|-------|
| Capacidades hosteadas (Proc, Fs) en cross-compilación | TAR002 |

### Runtime — Limitaciones de Ejecución

| Funcionalidad | Estado |
|---------------|--------|
| `zero dev --target wasm32-web` | ❌ Plan-only, no sirve requests (en macOS ni Linux) |
| WASM generado | `browser-worker` con import WASI `fd_write`, sin runtime de desarrollo |
| `std.fs`, `std.args`, `std.env`, `std.proc` en wasm32-web | ❌ No disponibles |
| Concatenación de strings | ❌ No existe; delegar a shell scripts |
| `Span<u8>` a `String` implícito | ❌ No existe |
| Interfaces / traits completos | ❌ Static dispatch con funciones concretas solamente |

---

## Experimentos de Arquitectura

Se diseñaron dos arquitecturas alternativas para lograr persistencia real con MongoDB. Ambas están completamente documentadas en `openspec/changes/` pero **no son funcionales** debido a CGEN004.

### 1. `native-mongodb-proxy-arch` — Zero CLI + Proxy Node.js

**Arquitectura:**
```
Browser/curl → Node.js/Express (HTTP proxy) → Zero CLI binary (temp-file IPC) → curl → MongoDB Data API
```

**Capas DDD:**
```
domain/ → application/ → infrastructure/ → presentation/
```

**Componentes:**
- **Node.js/Express proxy** (`proxy/index.js`): recibe HTTP, serializa a JSON, spawn Zero CLI, lee respuesta de temp file
- **Zero CLI** (`src/main.0`): dispatch por method+path, routing a shell scripts
- **Shell scripts** (`scripts/mongo-*.sh`): `jq` + `curl` para MongoDB Data API (find, insertOne, deleteOne, updateOne)
- **Docker**: multi-stage build Alpine, docker-compose con MongoDB 7

**Bloqueado por:**
- `std.fs.host()`, `std.fs.createOrRaise()`, `std.fs.writeAllOrRaise()`, `std.fs.read()` → CGEN004
- `std.proc.spawn()` → CGEN004
- `std.mem.len()` en contexto de comparación → CGEN004
- Comparaciones de strings (`==` sobre `String` o `Span<u8>`) → CGEN004
- Slicing de strings (`path[..7]`) → CGEN004

### 2. `zero-http-server` — Socat + Zero como HTTP Server Nativo

**Arquitectura:**
```
Browser/curl → socat (TCP acceptor) → Zero binary (stdin/stdout) → curl → MongoDB Data API
```

**Innovación:** Elimina Node.js por completo. Usa `socat TCP-LISTEN:8080,fork,reuseaddr EXEC:./todo-api` como acceptor TCP. Zero lee HTTP de stdin y escribe respuestas a stdout.

**Componentes:**
- **socat**: TCP acceptor (~200KB en Alpine), hace fork por conexión
- **http-wrapper.sh** (15 líneas): parsea HTTP request line con `read`, extrae method+path, invoca Zero con args
- **Zero CLI** (`src/main.0`): routing y dispatch sin cambios respecto a la arquitectura anterior
- **Shell scripts**: idénticos a los de `native-mongodb-proxy-arch`

**Bloqueado por:**
- Las mismas limitaciones de CGEN004 que afectan al backend nativo
- El wrapper bash existe como workaround para el HTTP parsing (que Zero no puede hacer)

**Ventajas sobre la arquitectura anterior (si el backend nativo funcionara):**
- Sin dependencia de Node.js/npm/Express (~50MB menos)
- Imagen Docker: solo `alpine + socat + jq + curl + Zero binary`
- Arquitectura más simple: 1 línea de socat reemplaza 55 líneas de Express

---

## DDD en Zero

El skill `zero-domain` documenta cómo estructurar Domain-Driven Design en Zero, respetando las restricciones del compilador v0.1.2.

### Regla de Oro: Flat Namespace

Todos los `pub fun` del package comparten un namespace plano. IMP003 bloquea dos funciones con el mismo nombre en distintos módulos.

### Convención de Nombres por Capa

| Capa | Prefijo | Ejemplo |
|------|---------|---------|
| domain/values | `isValid*`, `new*`, `done*` | `isValidTitle`, `newTodoId`, `doneDone` |
| domain/aggregate | `<aggregate>*` | `todoCreate`, `todoMarkDone` |
| infrastructure | `<adapter>*` | `mongoFind`, `fileWriteHealth` |
| application | `app*` | `appListTodos`, `appCreateTodo` |
| presentation | `route*` | `routeRequest` |

### Estructura de Capas Propuesta

```
src/
├── main.0                    # Wiring: args → router
├── domain/                   # Reglas de negocio (sin dependencias externas)
│   ├── values.0              # Value Objects + validators
│   └── todo.0                # Aggregate root
├── application/
│   └── usecases.0            # Orquestación: validar → ejecutar
├── infrastructure/
│   ├── mongo.0               # Adaptador de persistencia
│   └── files.0               # Adaptador de I/O
└── presentation/
    └── router.0              # HTTP → use case mapping
```

### Reglas de Dependencia

```
presentation → application → domain
presentation → application → infrastructure
     ↓              ↓
  NUNCA: domain → infrastructure
  NUNCA: domain → application
```

### Value Objects con Shapes

```zero
pub shape Title { value: String }
pub shape TodoId { value: String }
pub shape Done { value: Bool }

pub fun isValidTitle(raw: String) -> Bool { ... }
pub fun newTitle(raw: String) -> Title { ... }
```

### Aggregate Root

```zero
pub shape Todo {
    id: TodoId,
    title: Title,
    done: Done
}

pub fun todoCreate(id: TodoId, title: Title) -> Todo { ... }
pub fun todoMarkDone(self: mutref<Todo>) -> Void { ... }
```

### Anti-Patrones Documentados

| Anti-Patrón | Problema | Corrección |
|-------------|----------|------------|
| `pub fun` con mismo nombre en dos módulos | IMP003 | Prefijar con contexto |
| `Maybe<T>` como return type con valor directo | TYP003 | Usar `Bool` para validación |
| Coma final en shape literal: `field: value,` | PAR100 | Sin coma en último campo |
| `std.fs.write(path, span)` | STD003 | Usar `createOrRaise` + `writeAllOrRaise` |
| `strings[..]` comparado con `String` | TYP002 | Ambos lados como `Span<u8>`: `a[..] == b[..]` |
| `let` sin `mut` y reasignación | Error de compilación | `let mut` si se reasigna |
| `std.json` en módulo CLI | STD002 | Solo en web route handlers |

---

## MongoDB Data API — Shell Scripts

Los scripts de persistencia usan la MongoDB Data API (REST sobre HTTPS) porque Zero no puede hacerlo nativamente.

| Script | Endpoint Data API | Input | Output |
|--------|-------------------|-------|--------|
| `mongo-find.sh` | `POST /action/find` | — | JSON array de todos |
| `mongo-insert.sh` | `POST /action/insertOne` | `/tmp/req-body.json` | Todo creado con `_id` |
| `mongo-delete.sh` | `POST /action/deleteOne` | `/tmp/todo-id.txt` | `{"deleted":true}` o error |
| `mongo-update.sh` | `POST /action/updateOne` | `/tmp/req-body.json` + `/tmp/todo-id.txt` | Todo actualizado o error |

**Variables de entorno requeridas:**
- `MONGO_DATA_API_URL` — URL base del Data API
- `MONGO_API_KEY` — API key de MongoDB Atlas

**Flujo de IPC con temp files:**
```
Proxy/Wrapper → escribe /tmp/req-body.json + /tmp/todo-id.txt
              → spawn shell script
              → shell script lee temp files → curl MongoDB Data API
              → resultado escrito a /tmp/http-body.json
              → Proxy/Wrapper lee /tmp/http-body.json → HTTP response
```

---

## Docker Deployment

### Dockerfile (Multi-stage)

```dockerfile
# Stage 1: Build Zero binary
FROM alpine:latest AS builder
RUN apk add --no-cache curl bash
RUN curl -fsSL https://zerolang.ai/install.sh | bash
COPY zero.json src/ /src/
RUN zero build --emit exe . --out /app/todo-api || echo "build failed"

# Stage 2: Runtime
FROM alpine:latest
RUN apk add --no-cache curl jq bash socat
COPY scripts/ /app/scripts/
COPY --from=builder /app/todo-api /app/todo-api
CMD ["socat", "TCP-LISTEN:8080,fork,reuseaddr", "EXEC:sh /app/scripts/http-wrapper.sh"]
```

### docker-compose.yml

```yaml
services:
  api:
    build: .
    ports: ["8080:8080"]
    environment:
      - MONGO_DATA_API_URL=${MONGO_DATA_API_URL}
      - MONGO_API_KEY=${MONGO_API_KEY}
    depends_on:
      mongo:
        condition: service_healthy

  mongo:
    image: mongo:7
    ports: ["27017:27017"]
    volumes:
      - mongo_data:/data/db
```

**Nota:** El build del binario Zero falla en macOS y en Docker. La etapa de build tiene `|| echo "build failed"` como fallback porque CGEN004 impide la compilación a exe.

---

## Tests de Integración

`tests/integration.sh` — Suite de tests HTTP con curl:

| Test | Método | Ruta | Esperado |
|------|--------|------|----------|
| Health check | GET | `/` | 200, `"todo api running"` |
| Crear todo | POST | `/todos` | 201, campo `id` |
| Listar todos | GET | `/todos` | 200, contiene el id creado |
| Actualizar todo | PATCH | `/todos/:id` | 200, `"done": true` |
| Eliminar todo | DELETE | `/todos/:id` | 200, `"deleted"` |
| Verificar eliminado | GET | `/todos` | 200, array sin el id |
| DELETE no existente | DELETE | `/todos/invalid` | 404 |
| PATCH no existente | PATCH | `/todos/invalid` | 404 |
| CORS preflight | OPTIONS | `/todos` | 204 |
| Ruta no existente | GET | `/unknown` | 404 |

**Nota:** Los tests asumen un servidor corriendo en `http://localhost:8080`. Dado que el backend nativo no compila, estos tests no pueden ejecutarse actualmente.

---

## Roadmap

| Fase | Estado | Descripción |
|------|--------|-------------|
| 1. API con datos mock | ✅ Completado | `wasm32-web` con 3 todos hardcoded, health check |
| 2. CLI con archivos JSON | ⏳ Bloqueado | Requiere `std.fs` funcional en nativo (CGEN004) |
| 3. MongoDB vía shell scripts | ⏳ Bloqueado | Requiere `std.fs` + `std.proc` funcionales (CGEN004) |
| 4. HTTP server nativo | ⏳ Bloqueado | Requiere `std.net` I/O (no existe aún) |
| 5. DDD completo en capas | ⏳ Bloqueado | Requiere que todo lo anterior funcione |

---

## Skills de OpenCode Disponibles

| Skill | Descripción |
|-------|-------------|
| `zero-language` | Sintaxis y semántica del lenguaje Zero |
| `zero-builds` | Compilación, targets, profiles |
| `zero-diagnostics` | Lectura y reparación de errores del compilador |
| `zero-packages` | Manejo de paquetes y manifests |
| `zero-stdlib` | Biblioteca estándar de Zero |
| `zero-testing` | Tests en Zero |
| `zero-agent` | Flujo de trabajo para editar código Zero |
| `zero-web` | APIs web y route handlers |
| `zero-domain` | DDD en Zero: shapes, aggregates, validators, capas |

---

## Comandos de Verificación

```sh
# Verificar que el proyecto compila
zero check .

# Ver rutas web
zero routes --json .

# Compilar a WASM
zero build --emit wasm --target wasm32-web .

# Intentar compilar a exe nativo (falla con CGEN004)
zero build --emit exe .

# Ejecutar CLI nativo
zero run .

# Ver el WASM generado
ls -la .zero/out/
```

---

## Lecciones Aprendidas

1. **CGEN004 es el bloqueante universal.** Sin comparaciones de strings, sin `std.fs`, sin `std.proc`, sin `std.mem.len()`, el backend nativo no puede implementar ni siquiera un router HTTP básico.

2. **El target wasm32-web compila pero no ejecuta.** No hay runtime de desarrollo; `zero dev` es plan-only. El WASM generado requiere glue code externo.

3. **Zero v0.1.2 es pre-alpha para aplicaciones reales.** El subconjunto funcional del backend nativo se limita a Hello World, eco de argumentos, y bucles sobre enteros.

4. **La arquitectura DDD está diseñada y documentada.** Las capas, value objects, aggregates, y convenciones de nombres están listas para cuando el compilador madure.

5. **El ecosistema de scripts bash es funcional como workaround.** Los shell scripts con `jq` + `curl` manejan la persistencia MongoDB correctamente; el problema es que Zero no puede invocarlos.

6. **La barrera está en el backend, no en el diseño.** La arquitectura de capas, el HTTP server con socat, y el proxy Node.js son diseños sólidos. El único impedimento es el codegen del compilador.

7. **El tooling de Zero (zero check, zero routes, zero build wasm) funciona correctamente.** El problema no está en el frontend del compilador, sino en el backend de generación de código nativo.

---

## Referencias

- [Zero Language](https://zerolang.ai)
- [OpenCode](https://opencode.ai)
- [MongoDB Data API](https://www.mongodb.com/docs/atlas/api/data-api/)
- OpenSpec changes en `openspec/changes/`
- Skills del proyecto en `.opencode/skills/`
