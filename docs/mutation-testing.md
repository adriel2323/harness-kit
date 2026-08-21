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
| JS/TS    | `Stryker` (via `tools/stryker-runner.sh`, ver abajo)      |
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

## JS/TS: Stryker vía `tools/stryker-runner.sh`

`tools/mutate.py` **no sirve para JavaScript**. Tokeniza con el módulo
`tokenize` de Python y valida cada mutante con `compile()`, así que sobre un
`.js` descarta el 100% de los mutantes por "no compilar" y reporta un score
vacío — que se lee como "todo bien" cuando en realidad no se evaluó nada. Para
Node hay que usar Stryker.

Instalación en el proyecto (ajustá el runner a tu stack):

```bash
pnpm add -D @stryker-mutator/core @stryker-mutator/tap-runner
```

`tap-runner` es el que habla con el runner nativo `node --test` (Node emite TAP
con `--test-reporter=tap`). Para vitest/jest/mocha usá el runner propio de cada
uno.

### Por qué hay un wrapper y no `stryker run` a secas

El arnés pasa el archivo a mutar como **posicional**
(`run-mutation.sh src/foo.js`), y el único posicional de Stryker es su archivo
de **configuración**: `stryker run src/foo.js` lo hace buscar un config llamado
`src/foo.js`. `stryker-runner.sh` traduce los posicionales a `--mutate`, resuelve
el binario local (`node_modules/.bin/stryker`, sin atarse a npm/pnpm/yarn) y
envuelve todo en `guard-mem.sh`.

### Tres cosas que muerden al configurarlo

**1. Resolución de plugins con pnpm.** El default de Stryker es el glob
`['@stryker-mutator/*']`, que con el layout de symlinks de pnpm no resuelve. El
error es engañoso — *"Cannot find TestRunner plugin, no TestRunner plugins were
loaded. Did you forget to install it?"* — pero el plugin **está** instalado; lo
que falla es el descubrimiento. Declaralos explícitos:

```js
plugins: ['@stryker-mutator/tap-runner'],
```

**2. Handles abiertos = score inflado.** Si tus tests dejan un handle vivo (un
pool de Sequelize, un servidor sin cerrar), el proceso no termina, Stryker lo
cuenta como *timeout* y marca como **muertos** mutantes que en realidad
**sobreviven**. Un score inflado es peor que uno bajo: te dice que estás cubierto
cuando no lo estás. Con el runner nativo se ataja pasando el flag por `nodeArgs`:

```js
tap: { nodeArgs: ['--test-reporter=tap', '--test-force-exit', '-r', '{{hookFile}}', '{{testFile}}'] }
```

**3. Concurrencia.** El default de Stryker es `cpuCount - 1`: en una máquina de
8 cores son 7 procesos node simultáneos. En WSL con techo de memoria eso es
exactamente el patrón que puede tumbar la distro (ver la sección de techos, más
abajo). El kit lo baja a 2 vía `HARNESS_MUTATION_CONCURRENCY`. La mutación es
trabajo de fondo: que tarde más es preferible a competir con tu sesión.

## El scope: solo las líneas de la feature (automático)

El umbral se define sobre **las líneas nuevas o tocadas por la feature**, no
sobre el archivo entero. La diferencia no es cosmética. Medido sobre
`queryBuilder.js` el 2026-08-21:

| Qué se muta | Mutantes | Score | Gate |
|---|---|---|---|
| El archivo completo | 89 | 35.96% | rojo |
| Solo las líneas de la feature | 6 | 100% | verde |

Los 56 sobrevivientes del archivo completo son código viejo sin tests. Son un
problema real, pero **no son un problema de esta feature**, y mezclarlos hace
que el gate no diga nada útil: siempre rojo, siempre por el mismo motivo, hasta
que se lo empieza a ignorar.

`run-mutation.sh` saca el rango solo, del `git diff`. No hay que pasar nada:

```bash
bash tools/run-mutation.sh src/utils/citizen/queryBuilder.js
# -> src/utils/citizen/queryBuilder.js:89-101,src/utils/citizen/queryBuilder.js:113-114
```

Dos variables lo gobiernan:

- **`HARNESS_MUTATION_RANGE_FMT`** — cómo escribe rangos tu mutador. Stryker:
  `"{file}:{start}-{end}"`. **Vacío** = el mutador no soporta rangos y los
  archivos van enteros (`mutate.py`, PIT, cargo-mutants). Es el default.
- **`HARNESS_MUTATION_DIFF_BASE`** — contra qué se diffea. Default `HEAD`: el
  trabajo sin commitear. Si tu flujo hace commits a mitad de feature en una rama
  propia, apuntalo a la rama de integración (`origin/main`) o a un merge-base.

### Los dos casos borde, y por qué se resuelven así

**Archivo nuevo sin trackear** → se muta entero. No es un fallback: si el
archivo lo creó la feature, todas sus líneas *son* la feature.

**El archivo no tiene diff contra la base** → se muta entero, con un aviso
ruidoso por stderr. Esto es deliberado y va contra la lectura ingenua. Un rango
vacío le daría a Stryker cero mutantes, cero mutantes dan score 100%, y 100% da
**gate verde sobre cero evidencia** — el peor resultado posible, porque miente
en la dirección que nadie revisa. Caer al archivo entero falla hacia el rojo,
que es el lado seguro. Si ves ese aviso, casi siempre significa que la feature
ya está commiteada y `HARNESS_MUTATION_DIFF_BASE` te quedó en `HEAD`.

Un rango explícito que pases a mano (`archivo:85-130`) se respeta tal cual y no
se pisa.

## Techos de recursos: por qué un mutante puede tumbarte la máquina

Un mutante no solo cambia el resultado de una función: puede cambiar si la
función **termina**. `i = i - 1` mutado a `i = i + 1` dentro de un `while
i != 0` es un bucle infinito perfectamente válido y compilable. Sin defensas,
esa corrida de tests no falla: se cuelga, y crece.

Esto ya costó una sesión de máquina (2026-08-21). `mutate.py` corría los tests
con un `subprocess.run()` **sin timeout**; el envoltorio externo era un
`timeout -k 5 300 python3 …`, que mata al Python pero **no al nieto** (`timeout`
solo señaliza a su hijo directo). El proceso de tests quedó huérfano, creció a
10.1 GB de RSS, agotó 16 GB de swap y el OOM killer terminó apagando la distro
WSL completa.

Hay tres defensas, y hacen falta las tres porque cubren fallas distintas:

| Defensa | Dónde | Qué ataja |
|---|---|---|
| `--timeout` / `HARNESS_MUTATION_TIMEOUT` | `mutate.py` | El mutante que **no termina**. Default 120 s. |
| `start_new_session` + `killpg` | `mutate.py` | Los **nietos huérfanos** cuando se mata la corrida. |
| `HARNESS_MEM_MAX` | `tools/guard-mem.sh` | El proceso que **crece sin techo** dentro del timeout. |

### El timeout cuenta como mutante muerto

Y está bien que así sea: la suite no pasó, que es exactamente lo que se le pide
detectar. Se marca aparte en el log (`muerto(timeout)`) porque un timeout casi
siempre significa "este mutante generó un bucle infinito", no "un test hizo una
aserción" — es información distinta cuando leés el reporte.

Si la suite **sin mutar** se pasa del timeout, `mutate.py` sale con exit 2 y lo
dice explícitamente: no es un mutante, es tu suite (handles sin cerrar, un
runner que no termina) o un timeout demasiado bajo.

No pongas `--timeout 0` (sin límite). Es la configuración que produjo el
incidente.

### El techo de memoria

`tools/guard-mem.sh` mete el comando en un cgroup transitorio con `MemoryMax` y
`MemorySwapMax=0`:

```bash
bash tools/guard-mem.sh node --test tests/foo.test.js
```

Si el proceso se pasa de `HARNESS_MEM_MAX` (default `2G`), el kernel mata **solo
ese cgroup** y el comando sale con 137. Eso convierte "se murió la máquina" en
"murió ese test", que es una señal accionable. Ya lo aplican `run-tests.sh` y
los runners por lenguaje; si escribís un runner nuevo, pasá el comando por ahí.

Donde no haya cgroup v2 delegado (CI, contenedor, macOS, sin systemd),
`guard-mem.sh` avisa por stderr y corre el comando igual: nunca bloquea.
`HARNESS_MEM_MAX="off"` lo desactiva.

> No uses `ulimit -v` para esto. Limita espacio de direcciones **virtual**, y los
> runtimes con JIT reservan rangos virtuales enormes que no son memoria real (el
> proceso del incidente tenía 27 GB de virtual con 10 GB de RSS). Un `ulimit -v`
> lo bastante bajo para servir de techo hace fallar al runtime en el arranque.
> `MemoryMax` mide RSS real.

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
