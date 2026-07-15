# Prueba de mutación — validar que los tests muerden

> "Mutation testing is resource-heavy, but the ROI on code correctness is
> worth every cycle." / "We are shifting from a bottleneck of human typing
> speed to a bottleneck of compute-driven validation."

## El problema que resuelve

Una suite verde dice "el código no explota con estas entradas". **No** dice
"los tests fallarían si el código estuviera mal". Un test sin asserts
fuertes pasa siempre y no protege nada.

La prueba de mutación lo mide al revés: introduce un defecto pequeño en el
código (un *mutante*) y observa la suite.

- Si **algún test falla** → el mutante está **muerto** (killed). Bien: la
  red atrapó el defecto.
- Si **todos los tests pasan** → el mutante **sobrevive** (survived). Mal:
  hay un agujero. Falta un assert o un caso.

**Puntuación de mutación** = `killed / total`. Cuanto más alta, más muerden
los tests.

## Herramientas por lenguaje

El comando lo define `HARNESS_MUTATION_CMD` en `harness.config.sh`. Lo
natural es usar la herramienta madura de tu ecosistema:

| Lenguaje | Herramienta de mutación                                  |
|----------|-----------------------------------------------------------|
| Python   | `tools/mutate.py` (incluido, sin deps) · `mutmut` · `cosmic-ray` |
| JS/TS    | `Stryker` (`pnpm dlx stryker run`)                        |
| Go       | `go-mutesting` · `gremlins`                               |
| Rust     | `cargo-mutants`                                           |
| Java/Kt  | `PIT` (`pitest`)                                          |

## El mutador incluido: `tools/mutate.py`

Sin dependencias externas. Pensado para **Python** (trabaja a nivel de token,
así que nunca muta strings ni comentarios), pero el comando de tests es
configurable, así que respeta tu runner:

1. Lee un archivo de código.
2. Aplica, **uno a uno**, un catálogo de mutaciones:

   | Categoría    | Ejemplo de mutación                          |
   |--------------|----------------------------------------------|
   | Comparación  | `<=` → `<`, `==` → `!=`, `>` → `>=`          |
   | Aritmética   | `+` → `-`, `- 1` → `+ 1`                      |
   | Booleano     | `and` → `or`, `True` → `False`               |
   | Constantes   | `0` → `1`, `1` → `2`                          |
   | Retorno      | `return <expr>` → `return None`              |

3. Por cada mutante: escribe el archivo mutado, corre el comando de tests
   (`$HARNESS_TEST_CMD` o `--test-cmd`), restaura el original.
4. Reporta `total`, `killed`, `survived`, `score` y la lista de
   sobrevivientes (archivo:línea + mutación).

En el flujo del arnés, llama siempre al wrapper (carga el entorno y lee
`HARNESS_MUTATION_CMD` de `harness.config.sh`):

```bash
tools/run-mutation.sh                     # corre la mutación completa
```

Si necesitas llamar al script directamente (debug, exploración):

```bash
python3 tools/mutate.py src/cli.py                          # mutar un archivo (TODOS)
python3 tools/mutate.py src/cli.py --max 80                 # DEBUG: acota; si trunca → exit 3
python3 tools/mutate.py src/cli.py --test-cmd "python3 -m pytest -q"
```

El script **restaura siempre** el archivo original, incluso si lo
interrumpes (maneja la limpieza en `finally`).

### `--max` y la honestidad del score (evidencia completa o gate rojo)

Por defecto, `--max` **no tiene tope** (`None`): se evalúan **todos** los
mutantes válidos del archivo. Es la única forma en que el `score` es honesto,
porque el score se calcula sobre lo evaluado — si evaluás la mitad del
universo, un `100%` solo dice que la mitad medida está cubierta, no el todo.

`--max N` existe solo como herramienta de **debug** (acotar una corrida larga
mientras explorás). Pero si un `--max` explícito **trunca** la lista (deja
mutantes válidos sin evaluar), la corrida sale con **exit 3** y el resumen dice
`evaluados X de Y` (también en el `--progress-file`). Exit 3 es **gate rojo**:
evidencia incompleta no satisface el umbral, por mucho que el score de lo
medido diera 100%. El score sigue calculándose sobre lo evaluado (no se inventa
veredicto sobre lo no medido); lo que cambia es que ya no llega verde al gate.

Precedencia de los códigos de salida:

| Exit | Significado                                                        |
|------|-------------------------------------------------------------------|
| `0`  | todos los mutantes evaluados y todos muertos → **gate verde**     |
| `1`  | hay sobrevivientes (no truncado) → agujeros en la red             |
| `2`  | la suite está roja **sin mutar** → arreglá los tests primero      |
| `3`  | `--max` truncó → evidencia parcial → **gate rojo**                |

`3` manda sobre `1`: si además de truncar hay sobrevivientes, se reportan
igual, pero el código de salida es `3` (la evidencia parcial es el problema de
fondo).

> Para lenguajes que no sean Python, prefiere la herramienta nativa de la
> tabla de arriba; el catálogo textual de `mutate.py` es un *fallback* y
> puede mutar dentro de strings en sintaxis no-Python.

## `HARNESS_MUTATION_TEST_CMD`: fail-fast solo para la mutación

`HARNESS_MUTATION_TEST_CMD` (en `harness.config.sh`) es un comando de tests
**exclusivo de `run-mutation.sh`**, separado de `HARNESS_FEAT_TEST_CMD`. La
razón: `HARNESS_FEAT_TEST_CMD` la comparte el loop rápido de TDD
(`init.sh --fast`), donde interesa ver **todos** los fallos de una corrida
para iterar rápido. La mutación, en cambio, solo mira el returncode del
comando por cada mutante: le da igual si fallan 1 o 50 tests, el veredicto es
el mismo (muerto = returncode ≠ 0). Por eso ahí un flag "fail-fast" (`-x` en
pytest) es semánticamente neutro para el veredicto — el mutante muere igual
con el primer test que falla — y mucho más barato: los mutantes
**sobrevivientes** (los que importan, porque revelan el agujero) igual pagan
la suite completa del scope, pero los mutantes muertos ya no esperan al
último test.

El flag concreto de fail-fast depende de la herramienta del lenguaje (`-x` en
pytest; Stryker, `gremlins` y PIT traen su propio mecanismo de *bail-out*).
Por eso vive en config (`harness.config.sh`) y no está hardcodeado en
`run-mutation.sh` ni en `mutate.py`.

Cadena de fallback en `run-mutation.sh` (de mayor a menor prioridad):

1. `HARNESS_MUTATION_TEST_CMD` (si está definida y no vacía) — con `{scope}`
   sustituido por `HARNESS_FEAT_SCOPE` (aunque esté vacío: en ese caso corre
   la suite completa con fail-fast, que sigue siendo correcto).
2. `HARNESS_FEAT_TEST_CMD` + `HARNESS_FEAT_SCOPE` (comportamiento previo, sin
   fail-fast).
3. `HARNESS_TEST_CMD` (lo resuelve `mutate.py` si no se le pasa `--test-cmd`).

Como con el resto de los comandos del arnés, debe ser "plano" y
shlex-parseable (sin pipes, `&&` ni otros operadores de shell), porque
`mutate.py` lo parsea con `shlex.split`.

## El umbral

- Por defecto, la feature exige **`HARNESS_MUTATION_THRESHOLD`% de mutantes
  muertos sobre las líneas nuevas o tocadas** por esa feature (100% en los
  perfiles que trae el kit).
- Para código heredado no tocado por la feature, no se exige umbral (se mide,
  no se bloquea).
- Un mutante **equivalente** (no cambia el comportamiento observable) puede
  excluirse, pero **solo** con justificación explícita escrita en
  `progress/mutation_<name>.md`. Abusar de esta vía es hacer trampa al juez.

## Quién hace qué

- El `mutation_tester` **mide** y reporta. No edita código.
- Un mutante sobreviviente es trabajo del `tdd_craftsman`: escribe el test
  rojo que lo mata y vuelve a pasar por el `judge`. Es el ciclo de mejora
  compute-bound: el CPU encuentra el hueco, el artesano lo tapa con un test.

## Por qué vale el coste

Reejecutar toda la suite por cada mutante es caro. Pero ese es justo el
desplazamiento que describe el hilo: el límite ya no es lo rápido que
teclea un humano, sino cuánta validación puede pagar tu CPU. La corrección
del código es el retorno, y compensa cada ciclo.
