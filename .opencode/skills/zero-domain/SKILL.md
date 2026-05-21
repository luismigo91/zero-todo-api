---
name: zero-domain
description: Domain-Driven Design en Zero. Cubre shapes como value objects y aggregates, validators, arquitectura por capas, reglas de visibilidad, naming conventions para evitar IMP003, y patrones para separar dominio de infraestructura.
---

# Zero Domain

Cómo estructurar el dominio de una aplicación Zero usando principios DDD, respetando las restricciones del compilador v0.1.2.

## Regla de Oro: Flat Namespace

**Todos los `pub fun` del package comparten un mismo namespace plano.** El compilador rechaza dos funciones con el mismo nombre aunque estén en módulos distintos con `IMP003`.

```zero
// ❌ NO compila — IMP003
// src/a/mod.0:  pub fun hello()
// src/b/mod.0:  pub fun hello()

// ✅ Compila — nombres únicos
// src/a/mod.0:  pub fun aHello()
// src/b/mod.0:  pub fun bHello()
```

Los file modules (`src/x/y.0`) importan funciones como nombres planos, sin prefijo de módulo:

```zero
use domain.values   // file module → funciones disponibles como nombre pelado
// se llaman:  isValidTitle(raw), newTodoId(raw)
// NO:         values.isValidTitle(raw)
```

Los directory modules (`src/x/mod.0`) SÍ permiten acceso prefijado. Pero por simplicidad, esta skill recomienda file modules con naming explícito.

## Convención de Nombres

Prefijar cada función pública con el contexto del módulo para evitar colisiones:

| Capa | Prefijo | Ejemplo |
|---|---|---|
| domain/values | `isValid*`, `new*`, `done*` | `isValidTitle`, `newTodoId`, `doneDone` |
| domain/aggregate | `<aggregate>*` | `todoCreate`, `todoMarkDone` |
| infrastructure | `<adapter>*` | `mongoFind`, `fileWriteHealth` |
| application | `app*` | `appListTodos`, `appCreateTodo` |
| presentation | `route*` | `routeRequest` |

## Estructura de Directorios

```
src/
├── main.0                    ← Wiring: args → router
├── domain/                   ← Reglas de negocio, sin dependencias externas
│   ├── values.0              ← Value Objects + validators
│   └── todo.0                ← Aggregate root
├── application/
│   └── usecases.0            ← Orquestación: valida dominio → llama infra
├── infrastructure/
│   ├── mongo.0               ← Adaptador de persistencia
│   └── files.0               ← Adaptador de I/O
└── presentation/
    └── router.0              ← HTTP → use case mapping
```

### Regla de dependencias

```
presentation → application → domain
presentation → application → infrastructure
     ↓              ↓
  NUNCA: domain → infrastructure
  NUNCA: domain → application
```

El dominio no importa nada que no sea `std.*` u otros módulos de dominio.

## Value Objects

Usar `shape` para definir value objects. Cada VO tiene su propio validador.

```zero
// domain/values.0
use std.mem

pub shape Title {
    value: String
}

pub fun isValidTitle(raw: String) -> Bool {
    return std.mem.len(raw) > 0
}

pub fun newTitle(raw: String) -> Title {
    return Title { value: raw }
}
```

**Reglas para Value Objects:**
- Un shape por VO (Title, TodoId, Done, etc.)
- Un `isValid*` que devuelve `Bool` (no `Maybe<T>` — el compilador no auto-wrapea)
- Un constructor `new*` que asume input ya validado
- Sin lógica de negocio compleja (esa va en el aggregate)

**`Maybe<T>` en Zero:**
- Solo `null` es válido en contexto `Maybe<T>`
- `return value` donde value es `T` NO se auto-convierte a `Maybe<T>` (TYP003)
- Solución: usar `Bool` para validación, separar validación de construcción

## Aggregate Root

El aggregate encapsula las reglas de negocio y recibe value objects ya validados.

```zero
// domain/todo.0
use domain.values

pub shape Todo {
    id: TodoId,
    title: Title,
    done: Done
}

pub fun todoCreate(id: TodoId, title: Title) -> Todo {
    return Todo {
        id: id,
        title: title,
        done: values.doneDone()
    }
}

pub fun todoMarkDone(self: mutref<Todo>) -> Void {
    if self.done.value == false {
        self.done = values.doneDone()
    }
}
```

**Reglas para Aggregates:**
- El constructor (`todoCreate`) aplica invariantes (done = false por defecto)
- Los métodos de mutación protegen invariantes (no marcar done dos veces)
- Reciben value objects, no strings crudos
- Usan `self: mutref<T>` para métodos que modifican estado

## Application Layer

Los use cases orquestan: validan inputs con el dominio, luego delegan a infraestructura.

```zero
// application/usecases.0
use domain.values
use infrastructure.mongo
use infrastructure.files

pub fun appCreateTodo(world: World, rawTitle: String) -> i32 raises {
    if isValidTitle(rawTitle) == false {
        check fileWriteBadRequest()
        return 1
    }
    return mongoInsert(world)
}
```

**Reglas para Use Cases:**
- Reciben tipos crudos (String, i32) porque vienen del CLI
- Validan con el dominio ANTES de llamar a infraestructura
- Escriben respuestas de error vía `files.*` cuando la validación falla
- Devuelven códigos de salida (0 = ok, 1 = bad request, 2 = not found)

## Infrastructure Layer

Adaptadores que hablan con el mundo exterior. No contienen lógica de negocio.

```zero
// infrastructure/mongo.0
use std.proc

pub fun mongoFind(world: World) -> i32 {
    let status = std.proc.spawn("sh scripts/mongo-find.sh")
    return std.proc.exitCode(status)
}

// infrastructure/files.0
use std.fs

pub fun fileWrite(path: String, content: Span<u8>) -> Void raises {
    let fs = std.fs.host()
    let mut file = check std.fs.createOrRaise(fs, path)
    check std.fs.writeAllOrRaise(&mut file, content)
}

pub fun fileWriteHealth() -> Void raises {
    check fileWrite("/tmp/http-body.json",
        "{\"message\":\"todo api running\",\"version\":\"0.2.0\"}"[..])
}
```

**Reglas para Infraestructura:**
- Sin imports a `domain/` ni `application/`
- Funciones genéricas (`fileWrite`) + wrappers semánticos (`fileWriteHealth`)
- Manejo de archivos: `createOrRaise` + `writeAllOrRaise` (nunca `std.fs.write` con Span<u8>)

## Presentation Layer

Traduce HTTP a use cases. Sin lógica de negocio.

```zero
// presentation/router.0
use std.mem
use application.usecases
use infrastructure.files

pub fun routeRequest(world: World, method: String, path: String,
                      arg3: String, arg4: String) -> i32 raises {
    if method == "GET" && path == "/" {
        check fileWriteHealth()
        return 0
    }
    if method == "GET" && path == "/todos" {
        return appListTodos(world)
    }
    if method == "POST" && path == "/todos" {
        return check appCreateTodo(world, arg3)
    }

    let pathLen = std.mem.len(path)
    if pathLen > 7 && path[..7] == "/todos/"[..] {
        if method == "DELETE" { return check appDeleteTodo(world, arg3) }
        if method == "PATCH"  { return check appUpdateTodo(world, arg3) }
    }

    check fileWriteNotFound()
    return 2
}
```

**Reglas para Presentation:**
- Usa `==` para comparar strings (funciona en Zero)
- Usa `path[..7] == "/todos/"[..]` para comparar Span<u8> con Span<u8>
- Extrae IDs con `path[7..]` (el offset es fijo para la ruta conocida)
- No valida — delega a use cases

## Wiring (main.0)

El entry point solo lee argumentos y llama al router.

```zero
use std.args
use presentation.router

pub fun readArg(index: usize) -> String {
    let arg = std.args.get(index)
    if arg.has { return arg.value }
    return ""
}

pub fun main(world: World) -> Void raises {
    let method = readArg(1)
    let path = readArg(2)
    let arg3 = readArg(3)
    let arg4 = readArg(4)

    if method == "" || path == "" {
        check world.err.write("usage: todo-api <method> <path> [args...]\n")
        raise MissingArgs
    }

    let code = check routeRequest(world, method, path, arg3, arg4)
    if code == 0 { check world.out.write("OK\n") }
}
```

## Anti-Patrones

| Anti-Patrón | Problema | Corrección |
|---|---|---|
| `pub fun` con mismo nombre en dos módulos | IMP003 | Prefijar con contexto |
| `Maybe<T>` como return type con valor directo | TYP003 | Usar `Bool` para validación |
| Coma final en shape literal: `field: value,` | PAR100 | Sin coma en último campo |
| `std.fs.write(path, span)` | STD003 | Usar `createOrRaise` + `writeAllOrRaise` |
| `strings[..]` comparado con `String` | TYP002 | Ambos lados como `Span<u8>`: `a[..] == b[..]` |
| `let` sin `mut` y reasignación | error de compilación | `let mut` si se reasigna |
| `std.json` en módulo CLI | STD002 | Solo disponible en web route handlers |

## Restricciones de Zero v0.1.2

| Qué NO existe | Workaround |
|---|---|
| Interfaces / traits completos | Static dispatch con funciones concretas |
| `std.json` en CLI | Strings literales para JSON; delegar parsing a shell scripts |
| Concatenación de strings | Usar strings fijos; delegar formato a shell scripts |
| `Span<u8>` a `String` implícito | Mantener el tipo correcto en cada contexto |
| Auto-wrapping de `T` a `Maybe<T>` | Separar validación (`Bool`) de construcción |
| `a.hello()` para file modules | Llamar funciones por nombre pelado |
