# Instalación y adaptación por lenguaje

Este arnés es **agnóstico al lenguaje**. El proceso (spec → Gherkin → TDD →
review → mutación) es universal; lo único que cambia entre proyectos son los
**comandos**, y todos viven en un único archivo: `harness.config.sh`.

## 1. Instalar en tu proyecto

Desde la carpeta del kit:

```bash
./install.sh /ruta/a/tu/proyecto          # proyecto nuevo o existente
./install.sh /ruta/a/tu/proyecto --force  # sobreescribe archivos del arnés ya presentes
```

El instalador copia los archivos del arnés a la raíz del proyecto y **nunca
toca tu `src/`/código**. Para proyectos en producción es seguro: sin
`--force` no pisa nada que ya exista (te avisa qué saltó).

> El arnés **debe** vivir en la raíz del proyecto: Claude Code lee `CLAUDE.md`
> y `.claude/agents/` desde ahí. No lo dejes en una subcarpeta.

## 2. Detección de lenguaje

`install.sh` detecta el stack por archivos marcadores y copia el perfil
correspondiente a `harness.config.sh`:

| Lenguaje | Se detecta por                                  | Perfil           |
|----------|-------------------------------------------------|------------------|
| Python   | `pyproject.toml`, `setup.py`, `requirements.txt`| `profiles/python.sh` |
| Node/TS  | `package.json`                                  | `profiles/node.sh`   |
| Go       | `go.mod`                                         | `profiles/go.sh`     |
| Rust     | `Cargo.toml`                                     | `profiles/rust.sh`   |
| otro     | (nada de lo anterior)                           | `profiles/generic.sh` |

Si la detección falla o tu stack es mixto, se copia `generic.sh` con
marcadores `TODO:`. Rellénalos a mano o deja que el agente `harness_bootstrap`
lo haga (paso 4).

## 3. La config central: `harness.config.sh`

Es un archivo de shell que el resto del arnés **lee** (no se ejecuta solo;
`init.sh` lo hace `source`). Variables:

```sh
HARNESS_LANGUAGE="python"                              # etiqueta del stack
HARNESS_SRC_DIR="src"                                  # dónde vive el código
HARNESS_TESTS_DIR="tests"                              # dónde viven los tests
HARNESS_TEST_CMD="python3 -m unittest discover -s tests -q"   # suite, modo silencioso
HARNESS_TEST_VERBOSE_CMD="python3 -m unittest discover -s tests -v"  # suite, verboso
HARNESS_MUTATION_CMD="python3 tools/mutate.py"         # mutación (acepta un archivo)
HARNESS_MUTATION_THRESHOLD="100"                       # % mínimo de mutantes muertos
HARNESS_BUILD_CMD=""                                   # build/compilación (opcional)
HARNESS_LINT_CMD=""                                    # lint/format check (opcional)
HARNESS_RUNTIME_CHECK="python3 --version"              # comando que prueba el toolchain
```

Cambiar de `unittest` a `pytest`, de `pnpm test` a `npm test`, etc., es
**editar una línea aquí**. Nada más en el arnés hardcodea comandos.

## 4. Bootstrap (recomendado, dentro de Claude Code)

Abre Claude Code en la raíz del proyecto y pide:

> «Haz el bootstrap del arnés para este proyecto.»

El agente `harness_bootstrap`:

1. Confirma el lenguaje y los comandos de `harness.config.sh` (los corrige si
   la detección automática se quedó corta).
2. Verifica que el toolchain responde (`HARNESS_RUNTIME_CHECK`,
   `HARNESS_TEST_CMD` en vacío).
3. Rellena `docs/architecture.md` y `docs/conventions.md` con las reglas
   reales de tu stack y tu repo (capas, estilo, manejo de errores).
4. Para un proyecto **existente**, siembra `feature_list.json` con las
   features que quieras llevar por el flujo (no toca el código que ya tienes).

Tras el bootstrap, `./init.sh` debe terminar verde.

## 5. Mutación por lenguaje

El mutador incluido (`tools/mutate.py`) es **sin dependencias** y funciona muy
bien para Python (trabaja a nivel de token, no muta strings ni comentarios).
Para otros lenguajes, lo natural es apuntar `HARNESS_MUTATION_CMD` a la
herramienta nativa madura:

| Lenguaje | Herramienta de mutación recomendada    |
|----------|-----------------------------------------|
| Python   | `tools/mutate.py` (incluido) · `mutmut` · `cosmic-ray` |
| JS/TS    | `Stryker` (`pnpm dlx stryker run`)      |
| Go       | `go-mutesting` · `gremlins`             |
| Rust     | `cargo-mutants`                         |
| Java/Kt  | `PIT` (`pitest`)                        |

Los perfiles ya traen el comando habitual. Ver `docs/mutation-testing.md`.

## 6. Empezar a trabajar

```bash
./init.sh                                  # verde de punta a punta
```

En `feature_list.json`, deja una feature con `"status": "pending"` y
`"sdd": true`. Abre Claude Code y pide:

> «implementa la siguiente feature pendiente»

A partir de ahí, sigue el pipeline de `docs/workflow.md`: el `craftsman_lead`
orquesta, **para en la puerta humana** para que apruebes los escenarios
Gherkin, y solo cierra la feature cuando el `judge` aprueba y la mutación
supera el umbral.

## Resolución de problemas

- **`init.sh` dice que falta `harness.config.sh`** → no se copió un perfil.
  Copia uno a mano: `cp profiles/python.sh harness.config.sh`.
- **`HARNESS_LANGUAGE` está en `TODO`** → estás en el perfil `generic`. Edita
  `harness.config.sh` o corre el bootstrap.
- **El toolchain no está instalado** → `HARNESS_RUNTIME_CHECK` falla; instala
  el runtime antes de seguir (el arnés **para**, no inventa workarounds).
