# Convenciones de código

> **PLANTILLA.** El agente `harness_bootstrap` (o tú) rellena este documento
> con el estilo real de tu lenguaje/repo. Homogeneidad extrema: la IA predice
> mejor cuando el repositorio se parece a sí mismo en todas partes.
> Borra los marcadores `TODO:` cuando lo personalices.

## Estilo del lenguaje

- **Lenguaje / versión:** _TODO (p. ej. Python 3.11, Node 20 + TS 5, Go 1.22,
  Rust 2021)._
- **Formato / linter:** _TODO (p. ej. `black`+`ruff`, `prettier`+`eslint`,
  `gofmt`+`go vet`, `rustfmt`+`clippy`). Apúntalo en `HARNESS_LINT_CMD`._
- **Longitud de línea, imports, strings:** _TODO._

## Nombres

| Tipo                  | Convención        | Ejemplo            |
|-----------------------|-------------------|--------------------|
| Módulos / archivos    | _TODO_            | _TODO_             |
| Tipos / clases        | _TODO_            | _TODO_             |
| Funciones / variables | _TODO_            | _TODO_             |
| Constantes            | _TODO_            | _TODO_             |
| Privadas / internas   | _TODO_            | _TODO_             |

## Estructura de archivo

_TODO: cómo empieza un archivo típico (cabecera, orden de imports, docstring
de módulo)._

## Tests

- _TODO: un archivo de test por módulo/unidad; convención de nombres
  (`tests/test_<módulo>`, `<archivo>.test.ts`, `*_test.go`, módulo `#[cfg(test)]`…)._
- Cada test usa recursos reales aislados (directorios temporales, fixtures
  acotados) en vez de mockear el sistema cuando un recurso real es viable.
- Nombres de test descriptivos que digan qué comprueban.

## Manejo de errores

_TODO: cómo se modelan y propagan los errores en este lenguaje (excepciones
nombradas, `Result`/`error`, etc.). El borde de usuario captura, informa por
el canal de error y termina con código distinto de éxito; nunca propaga
stack traces crudos al usuario._

## Comentarios

Por defecto **no** se escriben. Solo se permiten cuando explican un *por qué*
no obvio (workaround documentado, invariante sutil). Los nombres hacen el resto.
