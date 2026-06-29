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
python3 tools/mutate.py src/cli.py                          # mutar un archivo
python3 tools/mutate.py src/cli.py --max 80                 # acotar nº de mutantes
python3 tools/mutate.py src/cli.py --test-cmd "python3 -m pytest -q"
```

El script **restaura siempre** el archivo original, incluso si lo
interrumpes (maneja la limpieza en `finally`).

> Para lenguajes que no sean Python, prefiere la herramienta nativa de la
> tabla de arriba; el catálogo textual de `mutate.py` es un *fallback* y
> puede mutar dentro de strings en sintaxis no-Python.

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
