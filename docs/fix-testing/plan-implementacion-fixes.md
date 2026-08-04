# Plan de implementación — fixes de workflow (delegación a opencode + velocidad de tests)

> **Para implementar por otro modelo.** Lee `docs/fix-testing/opencode-delegation-observability.md`
> y `docs/fix-testing/test-speed-optimization.md` (los diseños) antes de tocar nada.
> Este archivo es la versión *ajustada a lo que ya existe en código*: aplica solo lo faltante.

## 0. Alcance y destino

Dos repos involucrados (mismo árbol de archivos del arnés):

1. **Kit (template):** `craftsman-harness-kit/` — raíz de este repo.
2. **Downstream (instancia):** `~/munisn/salud/auditoria_vacunacion/responder_service/harness-kit/`.

Salvo `harness.config.sh` (el kit es plantilla TODO, el downstream está bootstrapped con
valores reales) y `mutate.py` (ver U1), los archivos a tocar son **idénticos** entre ambos.
Aplica los cambios en **los dos** salvo donde se indique lo contrario.

**Principio rector (no negociable):** separar el *gate de desarrollo* (rápido, scope de la
feat) del *gate de producción* (suite completa, una sola vez al cerrar). La suite completa
`HARNESS_TEST_CMD` **no se toca** y **sigue corriendo** en el `Stop` hook (`init.sh` sin flag).
Cero regresión: si `HARNESS_FEAT_SCOPE` está vacío, TODO cae al comportamiento actual.

## 1. Estado ya implementado (NO rehacer)

- **`tools/mutate.py` en el downstream** ya tiene: arg `--progress-file`, helper `_log()`
  (abre/escribe/cierra por mutante, sin buffer) y handler de SIGTERM vía
  `signal.default_int_handler` (que permite que el `try/finally` restaure el archivo ante
  un kill amable). **No modificar salvo para portar al kit (U1).**
- **`tools/pytest-runner.sh`** (downstream): normaliza el exit 5 de pytest (no tests ran)
  a éxito. Ya existe. No tocar.
- **`Stop` hook** y **`PostToolUse` hook** (`test-affected.sh`): ya correctos. No tocar.
- Modo de scope: **feat completo** (no el modo fino por-archivo mutado). El fino queda
  documentado como opt-in futuro.

## 2. Unidades de trabajo

### U1 — Portar `mutate.py` al kit (≈25 líneas)
**Solo en el kit.** El downstream ya lo tiene. Copiar textualmente desde
`~/munisn/salud/auditoria_vacunacion/responder_service/harness-kit/tools/mutate.py` hacia
`craftsman-harness-kit/tools/mutate.py`. Cambios concretos a portar:
- `import signal` + `signal.signal(signal.SIGTERM, signal.default_int_handler)` al nivel
  de módulo (esto hace que SIGTERM levante `KeyboardInterrupt` → entra al `try/finally`
  existente → restaura el archivo).
- Docstring: documentar `--progress-file` y la limitación de SIGKILL.
- Helper `_log(progress_file, line)`: abre en modo `"a"`, escribe, cierra (sin buffer).
- Arg `--progress-file`; si se pasa, trunca (`"w"`) con línea de arranque al inicio.
- Loguear: header de mutación, `test_cmd`, cada mutante `[i/total] mark describe`, la
  línea "archivo original restaurado" en el `finally`, y el resumen final.
- Mantener los `print(...)` existentes (stdout) intactos — el log es un canal extra.

**Verificación U1:** `python3 tools/mutate.py <arch> --progress-file /tmp/p.log` y confirmar
que `/tmp/p.log` crece línea a línea en vivo (no al final). Matar con `kill -TERM <pid>` a
mitad y confirmar que el archivo fuente vuelve a su estado original.

### U2 — `harness.config.sh`: variables de scope (≈5 líneas)
**En ambos repos.** Añadir, en una sección nueva "Scope de feat":
```bash
# --- Scope de feat (loop rápido + mutación) ---------------------------------
# Lista de test files (separados por espacio) de la feat EN CURSO. Vacío = cae a
# HARNESS_TEST_CMD (suite completa) como hasta hoy. Lo puebla el tdd_craftsman al
# empezar la feat; lo consumen mutate.py (vía run-mutation.sh) e init.sh --fast.
HARNESS_FEAT_SCOPE=""
# Comando que corre SOLO el scope. {scope} se reemplaza por $HARNESS_FEAT_SCOPE.
# Si el scope está vacío, los wrappers caen a HARNESS_TEST_CMD (safe default).
HARNESS_FEAT_TEST_CMD="bash harness-kit/tools/pytest-runner.sh -q {scope}"
```
- En el **kit** (template): usar `pytest-runner.sh` como referencia, pero dejar un
  comentario de que en otros stacks se ajusta al runner nativo.
- En el **downstream**: idéntico (ya usa `pytest-runner.sh` en `HARNESS_TEST_CMD`).
- **No** cambiar `HARNESS_TEST_CMD` ni `HARNESS_TEST_ONE_CMD`.

### U3 — `tools/run-mutation.sh`: resolver scope → `--test-cmd` (≈6 líneas)
**En ambos.** Antes del `exec`, resolver el scope y pasárselo a `mutate.py` como
`--test-cmd` (mucho más rápido: 1 archivo en vez de la suite completa por mutante):
```bash
# Si hay scope de feat, pasarlo como --test-cmd al mutador (más rápido). Si no,
# mutate.py lee $HARNESS_TEST_CMD como hasta hoy (suite completa).
SCOPE="${HARNESS_FEAT_SCOPE:-}"
FEAT_TEST_CMD="${HARNESS_FEAT_TEST_CMD:-}"
if [ -n "$SCOPE" ] && [ -n "$FEAT_TEST_CMD" ]; then
  RESOLVED="${FEAT_TEST_CMD//\{scope\}/$SCOPE}"
  exec bash -c "$CMD \"\$@\" --test-cmd \"$RESOLVED\"" _ "$@"
fi
exec bash -c "$CMD \"\$@\"" _ "$@"
```
Insertar entre el `case` de validación y el `exec` actual (reemplaza el `exec` único).
El `$CMD` es `HARNESS_MUTATION_CMD` ya validado. `--progress-file` **no** lo pasa el
wrapper: lo pasa el `mutation_tester` como arg extra (ver U5), que llega vía `"$@"`.

**Verificación U3:** con `HARNESS_FEAT_SCOPE` vacío, `run-mutation.sh <arch>` se comporta
igual que antes. Con scope poblado, los logs de mutate.py muestran `test_cmd` = solo el
scope, y el score debe ser idéntico al sin-scope (los tests que muerden no cambian).

### U4 — `init.sh`: flag `--fast` (≈12 líneas)
**En ambos.** Al inicio, parsear el flag; en el paso 6 (tests), bifurcar:
```bash
FAST=0
[ "${1:-}" = "--fast" ] && FAST=1
```
Y en el paso 6 reemplazar el bloque único por:
```bash
echo "── 6. Ejecutando tests ─────────────────────────────────"
if [ "$FAST" = "1" ] && [ -n "${HARNESS_FEAT_SCOPE:-}" ]; then
  CMD="${HARNESS_FEAT_TEST_CMD//\{scope\}/$HARNESS_FEAT_SCOPE}"
  if ( cd "$PROJECT_ROOT_ABS" && eval "$CMD" ) 2>&1; then
    ok "Tests del scope de feat pasan (--fast)"
  else
    fail "Tests del scope fallaron (--fast)"; EXIT_CODE=1
  fi
elif [ "$FAST" = "1" ]; then
  warn "--fast sin HARNESS_FEAT_SCOPE: paso de tests omitido (verificación intermedia)"
else
  if ( cd "$PROJECT_ROOT_ABS" && eval "$HARNESS_TEST_CMD" ) 2>&1; then
    ok "Todos los tests pasan"
  else
    fail "Hay tests rotos (o el comando de tests falló)"; EXIT_CODE=1
  fi
fi
```
**Sin flag → suite completa (idéntico a hoy).** El `Stop` hook sigue llamando `init.sh`
sin flag → gate de producción intacto.

**Verificación U4:** `./init.sh` (sin flag) = salida idéntica a la actual.
`./init.sh --fast` con scope vacío → warn, no FAIL. Con scope poblado → corre solo el scope.

### U5 — Prosa de agentes (≈20 líneas de prosa, en los dos perfiles)
**En ambos, en `.opencode/agents/` Y `.claude/agents/`.**

**`tdd_craftsman.md`:**
- En el paso 2 del protocolo, añadir: al empezar la feat, poblar `HARNESS_FEAT_SCOPE`
  en `harness.config.sh` con los test files que va a tocar (derivarlos del `.feature` +
  convención `tests/test_<name>.py`). Vaciarlo al cerrar la feat.
- En el ciclo ROJO/VERDE/REFACTOR: correr `HARNESS_FEAT_TEST_CMD` (no `HARNESS_TEST_CMD`).
- El paso 5 ("Ejecuta `./init.sh`") pasa a ser `./init.sh` **sin flag** (gate completo al
  final de la feat). Aclarar que durante el ciclo se usa `--fast`.

**`mutation_tester.md`:**
- Antes de cada `bash tools/run-mutation.sh <archivo>`, setear `HARNESS_FEAT_SCOPE` al
  scope de la feat (modo simple: feat completo). Pasar además
  `--progress-file <ruta-scratchpad>` para observabilidad (puede leerlo en vivo con `Read`).
- Aclarar: si aparecen sobrevivientes "raros", re-correr con suite completa (fallback:
  vaciar scope) antes de reportar FAIL — el scope angosta la red y puede dar falsos negativos.
- Recordar el handler de SIGTERM: ante un corte anormal, correr `./init.sh` antes de
  asumir código roto (mutante pegado > bug real).

**`judge.md`:**
- Reemplazar "Ejecuta `./init.sh`" por "Ejecuta `./init.sh --fast`" en su verificación
  intermedia. El gate de suite completa le queda al `Stop` hook / cierre del `craftsman_lead`.

### U6 — `craftsman_lead.md`: convención "prompt en frío cero" (≈15 líneas de prosa)
**En ambos** (downstream lo tiene en `../.claude/agents/craftsman_lead.md`; el kit en
`.claude/agents/craftsman_lead.md`). Añadir una subsección bajo "Resolución de modelo",
justo después del bloque "Cómo aplicar modo híbrido":

> **Prompt en frío cero (obligatorio al delegar a opencode Go).** Antes de lanzar
> `run-opencode.sh <fase> <prompt>`, el lead hace la investigación **él mismo** y el
> prompt-file le entrega al agente delegado:
> 1. El contrato de salida citado textual (las 4 líneas), no "leé `.claude/agents/X.md`".
> 2. Los comando(s) exacto(s) a correr, con todos los flags resueltos (rutas, `--max`,
>    `--test-cmd`, `--progress-file`, `HARNESS_FEAT_SCOPE`) — probados en seco por el lead.
> 3. La plantilla del reporte final ya dada (encabezados), no "mirá reportes anteriores".
> 4. Los hallazgos previos relevantes resumidos en texto (p. ej. puntos débiles del
>    `judge`), no "leé el veredicto del judge".
> 5. Confirmación explícita de baseline verde (con el número exacto de tests) para que el
>    agente no lo re-verifique.
>
> Esto reduce la fase de exploración del agente delegado (que en la primera corrida real
> de `mutation_tester` fue 33/35 min) a ~2 min. No elimina toda exploración (puede necesitar
> leer el fuente que muta), solo saca del camino lo que el orquestador ya sabe.

### U7 — Docs (≈20 líneas)
**En ambos.**

- `docs/verification.md`: añadir una sección "Modelo de 2 gates" que documente:
  - **Gate de desarrollo:** `./init.sh --fast` (scope de feat) durante TDD y review.
    Verificación intermedia; **no** habilita declarar `done`.
  - **Gate de producción:** `./init.sh` sin flag (suite completa), corrido por el
    `Stop` hook al cerrar. Único gate que valida integración completa.
  - `HARNESS_FEAT_SCOPE` vacío → todo cae a suite completa (cero regresión).
  - Umbral de mutación sigue 100%; las Tres Leyes del TDD no se relajan.

- `AGENTS.md` (tabla §2): en la fila de `init.sh` añadir mención de `--fast`, y añadir
  fila para `HARNESS_FEAT_SCOPE`/`HARNESS_FEAT_TEST_CMD` (o nota en la fila de
  `harness.config.sh`).

- Al pie de `docs/fix-testing/opencode-delegation-observability.md` y
  `docs/fix-testing/test-speed-optimization.md`: nota "IMPLEMENTADO ver
  `plan-implementacion-fixes.md`" con fecha.

## 3. Orden de implementación (dependencias)

```
U1 (kit, independiente) ─┐
U2 (independiente) ──────┼─→ U3 ──→ U5 (depende de U3+U4)
                         └─→ U4 ──→ U5
U6 (independiente) ──→ U7 (último, documenta todo)
```
U1 ∥ U2 ∥ U6 pueden ir en paralelo. U3 depende de U1+U2. U4 depende de U2. U5 depende de
U3+U4. U7 al final.

## 4. Verificación final (sin tocar tests)

1. `./init.sh` (sin flag) → verde, salida idéntica a la pre-cambio (regresión cero).
2. `./init.sh --fast` con `HARNESS_FEAT_SCOPE=""` → warn, no FAIL.
3. Poblar `HARNESS_FEAT_SCOPE="tests/test_<x>.py"` → `./init.sh --fast` corre solo ese
   archivo; `./init.sh` (sin flag) sigue corriendo la suite completa.
4. `bash tools/run-mutation.sh <arch> --progress-file /tmp/m.log` con scope poblado:
   - `/tmp/m.log` crece en vivo (no al final).
   - El `test_cmd` del log = solo el scope.
   - Score idéntico al correr con scope vacío (los tests que muerden no cambian).
5. `kill -TERM` a `mutate.py` a mitad → el fuente vuelve a su estado original.
6. `./init.sh` final verde.

## 5. Lo que NO cambia (invariantes)

- `HARNESS_TEST_CMD` (suite completa) se corre antes de producción (Stop hook /
  `init.sh` sin flag).
- Umbral de mutación = 100%.
- Tres Leyes del TDD (un test a la vez).
- Aprobación humana de los `.feature`.
- Contrato de 4 líneas de los subagentes.
- `Stop` y `PostToolUse` hooks: intactos.

## 6. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Scope mal poblado → mutante sobrevive por falta de test en scope (falso agujero) | Safe default (vacío → suite completa). `mutation_tester` re-corre con suite completa si sobrevivientes son raros. |
| `tdd_craftsman` se olvida de poblar `HARNESS_FEAT_SCOPE` | `init.sh --fast` advierte si está vacío. `judge` verifica el scope poblado en su checklist. |
| Alguien confunde `--fast` con el gate real | `docs/verification.md` lo deja claro. `craftsman_lead` **no** flipea `done` con `--fast` solo. |
| SIGKILL sigue sin atraparse | Limitación del SO, documentada. Ante corte anormal, correr `./init.sh` antes de asumir código roto. |
