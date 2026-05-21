# AGENTS.md

Zero project — API de tareas (todo-api) usando el lenguaje Zero (v0.1.2).

## Toolchain

```sh
# El compilador se instala con:
curl -fsSL https://zerolang.ai/install.sh | bash
export PATH="$HOME/.zero/bin:$PATH"

# Comandos principales
zero check .                     # Verificar el proyecto completo
zero routes --json .             # Ver las rutas web detectadas
zero dev --target wasm32-web .   # Servidor de desarrollo local
zero run .                       # Ejecutar el CLI
```

## Estructura

```
zero/
  zero.json       # targets.cli + targets.web
  src/
    main.0        # CLI entry (necesario para que zero check pase)
    routes/
      index.0     # GET /
      todos.0     # GET /todos, POST /todos
  scripts/        # MongoDB shell scripts (para cuando el backend nativo madure)
    mongo-find.sh
    mongo-insert.sh
    mongo-delete.sh
    mongo-update.sh
    http-wrapper.sh
  tests/
    integration.sh
```

## Reglas de proyecto

- **El CLI target es obligatorio**: `zero check .` requiere `targets.cli.main` en `zero.json`, incluso si el objetivo real es web. Sin él da `PAR100`.
- **Los route handlers exportan funciones con nombre de método HTTP** (`GET`, `POST`, etc.). Reciben `Request` y devuelven `Response`.
- **El path de ruta sale del nombre del archivo**: `src/routes/todos.0` → `/todos`.
- **JSON se construye explícitamente**: usar `std.json.object()`, `std.json.putString()`, `std.json.serialize()`.
- **Web WASM no tiene filesystem**: `std.fs`, `std.args`, `std.env`, `std.proc` no están disponibles en target `wasm32-web`.
- **Los tipos no se convierten implícitamente**: usar `as` para casts explícitos.
- **Los efectos son capacidades explícitas**: usar `World`, no stdout/stderr global.
- **Coma final en shape literals causa PAR100**: `Point { x: 1, y: 2, }` → error. Sin coma: `Point { x: 1, y: 2 }`.
- **Comparación de strings**: usar `==` entre `String` y `String`, o `Span<u8>` y `Span<u8>`. No mezclar tipos (TYP002).
- **`std.fs.write(path, span)` no compila (STD003)**: usar `createOrRaise` + `writeAllOrRaise` con `owned<File>`.
- **`let` sin `mut` no permite reasignación**: usar `let mut` si se necesita reasignar.
- **`std.json` solo en web route handlers**: no funciona en módulos CLI (STD002). En CLI usar strings literales.

## Limitaciones conocidas de Zero v0.1.2

### Backend nativo — qué SÍ es ejecutable (probado en Docker linux/amd64)

El backend `--emit exe` solo produce binarios funcionales para este subconjunto:

```zero
// ✅ Hello World — 241 B
pub fun main(world: World) -> Void raises {
    check world.out.write("hola desde Zero\n")
}

// ✅ Eco de argumentos — 354 B
use std.args
pub fun main(world: World) -> Void raises {
    let a = std.args.get(1)
    if a.has {
        check world.out.write(a.value)
        check world.out.write("\n")
    }
}

// ✅ Contador — 332 B
pub fun main(world: World) -> Void raises {
    let mut i: i32 = 1
    while i <= 5 {
        check world.out.write(".")
        i = i + 1
    }
    check world.out.write("\n")
}
```

**Lo que SÍ compila y ejecuta:**
- `world.out.write("texto")`
- `std.args.get(index)` — leer argumentos (sin comparar con `==`)
- Control flow: `if`/`else`, `while`, `for` (sobre enteros)
- Aritmética de enteros: `+`, `-`, `*`, comparaciones (`==`, `<`, `>`)
- `let`, `let mut`, reasignación de enteros
- Funciones que devuelven `i32`, `Void`

**Lo que NO compila a exe** (CGEN004):
- `==` sobre strings: `method == "GET"` → CGEN004
- `==` sobre `Span<u8>`: `path[..7] == "/todos/"[..]` → CGEN004
- `std.fs.*`: `host()`, `read()`, `createOrRaise()`, `writeAllOrRaise()` → CGEN004
- `std.proc.spawn()` → CGEN004
- `std.mem.len()` en contexto de comparación → CGEN004
- Slicing de strings con `path[..7]` → CGEN004
- `zero build --emit exe` en `darwin-arm64` → CGEN004 (backend no implementado)
- `zero dev --target wasm32-web` → plan-only, no arranca servidor (en macOS ni Linux)

### Backend WASM (compila pero no ejecuta)

El target `wasm32-web` compila correctamente pero no tiene runtime para desarrollo local:
- `zero check .` → ✅ 0 diagnostics
- `zero routes --json .` → ✅ detecta rutas
- `zero build --emit wasm --target wasm32-web .` → ✅ genera .wasm (160 B)
- `zero dev --target wasm32-web .` → ❌ plan-only, no sirve requests
- WASM generado es `browser-worker` con import WASI `fd_write`
- `frameworkTaxBytes: 0`

### Imports y visibilidad

- **File modules** (`src/x/y.0`): funciones `pub` se importan como nombres planos (sin prefijo de módulo)
- **Directory modules** (`src/x/mod.0`): permiten acceso prefijado (`x.funcion()`)
- **IMP003**: dos `pub fun` con el mismo nombre en distintos módulos → error. Usar naming único por capa.
- **TAR002**: capacidades hosteadas (Proc, Fs) solo disponibles en el host target. Cross-compilación las rechaza.

## Experimentos de arquitectura (documentados para referencia)

Se exploraron dos arquitecturas alternativas para persistencia con MongoDB. Ambas están documentadas como changes de OpenSpec pero **no son funcionales** debido a las limitaciones del backend nativo:

### `native-mongodb-proxy-arch` (openspec/changes/)
- Zero CLI nativo + Node.js proxy HTTP + MongoDB Data API vía shell scripts
- Arquitectura DDD: domain → application → infrastructure → presentation
- Bloqueado por: backend nativo no soporta `std.fs`, `std.proc`, ni comparaciones de strings

### `zero-http-server` (openspec/changes/)
- Socat como TCP acceptor + Zero leyendo HTTP de stdin
- Sin Node.js, wrapper bash de 15 líneas para HTTP parsing
- Bloqueado por: backend nativo no soporta operaciones básicas de strings

### Skill `zero-domain` (.opencode/skills/zero-domain/)
Documenta cómo estructurar DDD en Zero: shapes como value objects/aggregates, validators con `Bool`, naming conventions para evitar IMP003, arquitectura por capas, y anti-patrones. Válido para cuando el compilador madure.

## Roadmap

1. **Hoy**: API funcional vía `wasm32-web` con datos mock (hardcoded)
2. **Cuando Zero soporte `std.fs` en nativo**: migrar a CLI con archivos JSON locales
3. **Cuando Zero soporte `std.proc` en nativo**: integrar MongoDB vía shell scripts
4. **Cuando Zero soporte `std.net` I/O**: eliminar proxy/socat, HTTP server nativo en Zero
5. **Cuando Zero soporte DDD completo**: restaurar arquitectura en capas documentada en `zero-domain`

## OpenSpec workflow

Este proyecto usa OpenSpec para spec-driven development. Antes de codificar cambios significativos, usar:

```
/opsx:propose <descripción>   # Crear proposal, specs, design, tasks
/opsx:apply                   # Implementar las tareas
/opsx:archive                 # Merge specs y archivar el cambio
```

Los specs base están en `openspec/specs/`. Los cambios activos en `openspec/changes/`.

## Skills disponibles

Skills a nivel de proyecto en `.opencode/skills/`:
- `zero-language` — Sintaxis y semántica del lenguaje
- `zero-builds` — Compilación, targets, profiles
- `zero-diagnostics` — Lectura y reparación de errores
- `zero-packages` — Manejo de paquetes y manifests
- `zero-stdlib` — Biblioteca estándar
- `zero-testing` — Tests
- `zero-agent` — Flujo de trabajo para editar código Zero
- `zero-web` — APIs web y route handlers
- `zero-domain` — DDD en Zero: shapes, aggregates, validators, naming, capas
