# Plan: Reducción de tiempo de tests por feat

> **Estado:** propuesta — pendiente de aprobación humana
> **Autoría:** análisis del flujo SDD del Craftsman Harness
> **Objetivo:** bajar el costo de evaluación de una feat de **25-40 min** a
> **~5-10 min**, sin perder el gate de suite completa antes de producción.

---

## 1. Diagnóstico: dónde se va el tiempo

La suite completa es `python3 -m pytest -q tests` (19 archivos contra un
Postgres real en Docker). No hay unit/integration split; todos los tests son
de integración con `TestClient` + DB real. Cada corridión de la suite
completa cuesta **~1-2 min** (arranque de fixtures + truncado de tablas por
test).

El tiempo **no** se va en un solo sitio: se acumula en **4 puntos** que
invocan la suite completa:

| Punto | Quién lo dispara | Frecuencia por feat | Comando |
|-------|------------------|---------------------|---------|
| **Ciclo TDD** | `tdd_craftsman`, por cada `@s` | `@s` × (rojo+verde+refactor) ≈ 10-20 veces | `HARNESS_TEST_CMD` (suite completa) |
| **Gate del juez** | `judge`, al final | 1 vez | `./init.sh` → paso 6 (suite completa) |
| **Mutación** ⚠️ | `mutation_tester`, por cada mutante | **30-60 veces** (uno por mutante generado) | `HARNESS_TEST_CMD` una vez por mutante |
| **Cierre de sesión** | `Stop` hook | 1 vez | `./init.sh` → paso 6 (suite completa) |

### El cuello de botella real: la mutación

`mutate.py` (`harness-kit/tools/mutate.py:149`) llama a `run_tests(test_cmd)`
**una vez por mutante**. Para `responder/panel.py` (función grande), se
generan 30-60 mutantes válidos → 30-60 ejecuciones de la suite de 19
archivos. **Eso solo ya son 15-30 min.** Es, con diferencia, el principal
consumidor.

### Lo que ya está bien

El hook `PostToolUse` (`test-affected.sh`) **ya** corre solo el test file
del archivo editado. El loop rápido de feedback está resuelto. El problema
es que `tdd_craftsman` y `mutate.py` **no usan ese mecanismo** — caen al
`HARNESS_TEST_CMD` completo por diseño (no hay una variable de "scope de
feat").

---

## 2. Principio rector

> **Separar el gate de desarrollo (rápido, scope de la feat) del gate de
> producción (suite completa).**

- Durante el desarrollo y la mutación: solo los tests **relevantes** a la
  feat en curso.
- Antes de cerrar / declarar `done` / abrir PR: la **suite completa**, una
  sola vez, como gate de producción.

Esto NO reduce cobertura: la suite completa sigue corriendo donde importa
(cierre). Reduce **redundancia**: hoy corremos 19 archivos para validar un
cambio en 1 módulo, decenas de veces.

---

## 3. Implementación — Opción A (la recomendada)

### Visión general

| Variable | Propósito | Default |
|----------|-----------|---------|
| `HARNESS_TEST_CMD` | Suite completa — **gate de producción** (sin cambios) | `... pytest -q tests` |
| `HARNESS_FEAT_SCOPE` | Lista de test files de la feat en curso (vacío → cae a `HARNESS_TEST_CMD`) | `""` |
| `HARNESS_FEAT_TEST_CMD` | Comando que corre **solo** el scope de la feat | `... pytest -q {scope}` |

**Invariante de seguridad:** si `HARNESS_FEAT_SCOPE` está vacío, todo cae
al `HARNESS_TEST_CMD` actual. **Cero regresión** si no se pobla el scope.

### 3.1. `harness.config.sh` — añadir las variables de scope

```bash
# --- Scope de feat (loop rápido + mutación) ---------------------------------
# Lista de test files (separados por espacio) de la feat EN CURSO. Vacío = el
# agente/cae a HARNESS_TEST_CMD (suite completa) como hasta hoy. Lo puebla el
# tdd_craftsman al empezar la feat y lo consume mutate.py + init.sh --fast.
HARNESS_FEAT_SCOPE=""

# Comando que corre SOLO el scope. {scope} se reemplaza por $HARNESS_FEAT_SCOPE.
# Si el scope está vacío, los wrappers caen a HARNESS_TEST_CMD (safe default).
HARNESS_FEAT_TEST_CMD="bash harness-kit/tools/pytest-runner.sh -q {scope}"
```

### 3.2. `mutate.py` — aceptar `--test-cmd` con scope (el 80% del ahorro)

`mutate.py` ya soporta `--test-cmd` (`harness-kit/tools/mutate.py:59-63`).
El cambio es **en el wrapper**, no en el mutador:

**`run-mutation.sh`** — resolver el scope antes de delegar:

```bash
# Si hay scope de feat, pasarlo como --test-cmd al mutador (mucho más rápido).
# Si no, mutate.py lee $HARNESS_TEST_CMD como hasta hoy (suite completa).
FEAT_TEST_CMD="${HARNESS_FEAT_TEST_CMD:-}"
SCOPE="${HARNESS_FEAT_SCOPE:-}"
if [ -n "$SCOPE" ] && [ -n "$FEAT_TEST_CMD" ]; then
  RESOLVED="${FEAT_TEST_CMD//\{scope\}/$SCOPE}"
  exec bash -c "$CMD \"\$@\" --test-cmd \"$RESOLVED\"" _ "$@"
fi
exec bash -c "$CMD \"\$@\"" _ "$@"
```

**Resultado:** la mutación corre solo el test file del módulo mutado (1
archivo, no 19). Para un `panel.py` con 40 mutantes: de ~40 × suite completa
a ~40 × 1 archivo. **Ahorro estimado: 80-90% del tiempo de mutación.**

### 3.3. `run-mutation.sh` + `mutate.py` — mutación por archivo, no por suite

Refuerzo de la 3.2: el `mutation_tester` ya itera archivo por archivo (ver
su protocolo, paso 3). Para que cada archivo mute con su **propio** test
file, el `mutation_tester` debe setear `HARNESS_FEAT_SCOPE` al test file
que cubre el código mutado (lo saca del mapa `@s → test` en
`progress/tdd_<name>.md`).

Dos modos soportados:

- **Scope de feat completo** (todos los test files de la feat): simple,
  un poco menos fino. Set and forget.
- **Scope por archivo mutado** (el test file que cubre ese módulo): óptimo.
  El `mutation_tester` actualiza `HARNESS_FEAT_SCOPE` antes de cada
  `run-mutation.sh <archivo>`.

Empezar con el modo "scope de feat completo" (más simple); el modo por
archivo es una optimización posterior.

### 3.4. `tdd_craftsman` — loop con scope, suite completa al final

Cambio en el agente (`.opencode/agents/tdd_craftsman.md` y
`.claude/agents/tdd_craftsman.md`):

- Al empezar la feat, poblar `HARNESS_FEAT_SCOPE` en `harness.config.sh`
  con los test files que va a tocar (los deriva del `.feature` y la
  convención `tests/test_{name}.py`).
- En el ciclo rojo→verde→refactor, correr `HARNESS_FEAT_TEST_CMD` (no
  `HARNESS_TEST_CMD`).
- Al **final** de la feat (paso 5 del protocolo actual: "Ejecuta
  `./init.sh`"), correr la suite completa **una sola vez** como gate.

> Nota: el `PostToolUse` hook (`test-affected.sh`) ya corre el test
> individual tras cada `Edit|Write`. El cambio del `tdd_craftsman` hace
> que sus invocaciones **explícitas** de tests también sean con scope.

### 3.5. `init.sh` — flag `--fast`

Añadir un flag opcional:

```bash
./init.sh           # suite completa (gate de producción, sin cambios)
./init.sh --fast    # omite el paso 6 (tests), o corre solo el scope de feat
```

Implementación mínima en `init.sh`:

```bash
FAST=0
[ "${1:-}" = "--fast" ] && FAST=1
# ...
echo "── 6. Ejecutando tests ─────────────────────────────────"
if [ "$FAST" = "1" ] && [ -n "${HARNESS_FEAT_SCOPE:-}" ]; then
  CMD="${HARNESS_FEAT_TEST_CMD//\{scope\}/$HARNESS_FEAT_SCOPE}"
  ( cd "$PROJECT_ROOT_ABS" && eval "$CMD" ) 2>&1 && ok "Tests del scope de feat pasan" \
    || { fail "Tests del scope fallaron"; EXIT_CODE=1; }
elif [ "$FAST" = "1" ]; then
  warn "--fast sin HARNESS_FEAT_SCOPE: paso de tests omitido (verificación intermedia)"
else
  # comportamiento actual: suite completa
  ( cd "$PROJECT_ROOT_ABS" && eval "$HARNESS_TEST_CMD" ) 2>&1 && ok "Todos los tests pasan" \
    || { fail "Hay tests rotos"; EXIT_CODE=1; }
fi
```

**Uso:**
- `tdd_craftsman` y `judge` usan `./init.sh --fast` durante la feat.
- El `Stop` hook (`.claude/settings.json`) sigue llamando `init.sh` **sin**
  flag → suite completa = gate de producción, sin cambios.

### 3.6. `judge` — verificación con scope

El `judge` corre `./init.sh` para verificar. Cambio: que corra
`./init.sh --fast` durante el review, y deje la suite completa para el
gate de cierre del `craftsman_lead` (o el `Stop` hook). El `judge` ya
valida cobertura `@s → test` leyendo `progress/tdd_<name>.md`, así que su
valor agregado no depende de la suite completa.

### 3.7. Resumen de cambios por archivo

| Archivo | Cambio | Tamaño |
|---------|--------|--------|
| `harness-kit/harness.config.sh` | +2 variables (`HARNESS_FEAT_SCOPE`, `HARNESS_FEAT_TEST_CMD`) | ~5 líneas |
| `harness-kit/tools/run-mutation.sh` | resolver scope → `--test-cmd` | ~6 líneas |
| `harness-kit/init.sh` | flag `--fast` +分支 en paso 6 | ~12 líneas |
| `harness-kit/.opencode/agents/tdd_craftsman.md` | poblar scope + correr `FEAT_TEST_CMD` en loop | ~10 líneas de prosa |
| `harness-kit/.claude/agents/tdd_craftsman.md` | idem | ~10 líneas |
| `harness-kit/.opencode/agents/mutation_tester.md` | setear `HARNESS_FEAT_SCOPE` antes de mutar | ~5 líneas |
| `harness-kit/.claude/agents/mutation_tester.md` | idem | ~5 líneas |
| `harness-kit/.opencode/agents/judge.md` (si existe) | `./init.sh --fast` en review | ~2 líneas |
| `harness-kit/docs/verification.md` | documentar `--fast` y el modelo de 2 gates | ~20 líneas |

**Total: ~75 líneas, sin tocar ni un test.** La suite completa queda intacta
como gate de producción.

### 3.8. Estimación de impacto

| Fase | Antes | Después (Opción A) |
|------|-------|---------------------|
| Ciclo TDD (10-20 iter) | 10-20 × suite completa | 10-20 × scope (1-3 archivos) + 1 suite al final |
| Judge | 1 × suite completa | 1 × scope (fast) |
| Mutación (40 mutantes) | 40 × suite completa ⚠️ | 40 × scope (1 archivo) |
| Stop hook | 1 × suite completa | 1 × suite completa (sin cambios) |
| **Total por feat** | **25-40 min** | **~5-10 min** |

---

## 4. Elementos de las otras opciones que vale la pena considerar

### 4.1. De la Opción B (markers pytest) — selección semántica robusta

**Lo que aporta:** el scope por lista de archivos (`HARNESS_FEAT_SCOPE`)
es frágil si un `@s` toca varios módulos o si el `tdd_craftsman` se olvida
de actualizar la lista. Un marker `@pytest.mark.feature("<name>")` en cada
test file hace la selección **automática y auto-verificable**: pytest
falla si un marker no está registrado, y `pytest --markers` lista el
inventario.

**Cuándo migrar a B:** si la base de tests crece y el scope manual se vuelve
error-prone. Por ahora, con 19 archivos y una feat a la vez, A es
suficiente. Pero **dejar la puerta abierta**: la convención de nombres
`tests/test_{name}.py` ya da selección implícita por archivo, que es lo que
A explota. Migrar a markers después es trivial (un decorador por archivo).

**Híbrido posible hoy:** registrar markers en `conftest.py` **sin**
obligar a decorar. Solo documenta la convención para el futuro. Casi gratis.

### 4.2. De la Opción C (mapa `@s → test` declarativo) — scope por archivo mutado

**Lo que aporta:** el `tdd_craftsman` **ya** escribe
`progress/tdd_<name>.md` con el mapa `@s → test` (ver su protocolo, paso 4).
Ese mapa es la fuente de verdad más fina: para mutar `panel.py`, el
`mutation_tester` puede leer el mapa y saber **exactamente** qué test file
cubre ese módulo, en vez de mutar contra todos los test files de la feat.

**Cómo integrarlo en A (sin adoptar C completo):** el `mutation_tester`,
antes de mutar `<archivo>`, busca en `progress/tdd_<name>.md` qué test(s)
cubren ese archivo y setea `HARNESS_FEAT_SCOPE` a esa sub-lista. Es la
optimización "modo por archivo mutado" mencionada en §3.3. **No requiere
cambios en los tests** — solo que el `mutation_tester` lea el mapa que ya
existe.

**Riesgo:** depende de que el `tdd_craftsman` mantenga el mapa fiel. Hoy es
best-effort. Si el mapa está incompleto, el scope queda chico y un mutante
podría "sobrevivir" por falta de test en el scope (falso negativo de la red
real). **Mitigación:** si el score de mutación baja raro, correr la mutación
con scope de feat completo (fallback) o con la suite completa.

### 4.3. Optimización ortogonal: cache de mutación

`mutate.py` hoy no cachea: si muta el mismo archivo dos veces (p. ej. tras
un refactor menor del `judge`), re-ejecuta todo. Un cache simple
(`.mutmut-cache/` ya está en el `permissions.deny` de `.claude/settings.json`,
así que el patrón ya se contempló) con hash del archivo + test_cmd evitaría
re-trabajo. **Esto es independiente de A/B/C** y se puede sumar después.

### 4.4. Optimización ortogonal: `pytest-xdist` (paralelismo)

Si el cuello es I/O (DB), correr los tests en paralelo
(`pytest -n auto` con `pytest-xdist`) puede reducir la suite completa de
~2 min a ~30s. **Cuidado:** los fixtures de `conftest.py` truncán tablas
compartidas por test → necesitarían esquemas por worker o locks. Es la
optimización de mayor impacto para el gate de producción, pero **requiere
tocar los fixtures**, no solo el harness. Dejar para una segunda iteración.

---

## 5. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Scope mal poblado → mutante sobrevive por falta de test en scope (falso agujero) | (a) Safe default: scope vacío → suite completa. (b) `mutation_tester` documenta el score con scope vs. el esperado; si hay sobrevivientes raros, re-corre con suite completa. |
| `tdd_craftsman` se olvida de poblar `HARNESS_FEAT_SCOPE` | `init.sh --fast` lo detecta y advierte (warn) si el scope está vacío. El `judge` verifica que el scope esté poblado como parte de su checklist. |
| Regresión: alguien confunde `--fast` con el gate real | Documentar claramente en `docs/verification.md`: `--fast` = verificación intermedia; `init.sh` sin flag / `Stop` hook = gate de producción. El `craftsman_lead` **no** flipea `done` con `--fast` solo. |
| Scope por archivo mutado (§4.2) da falsos negativos | Empezar con scope de feat completo (§3.3, modo simple); el por-archivo es opt-in. |

---

## 6. Plan de ejecución (pasos ordenados)

1. **`harness.config.sh`** — añadir `HARNESS_FEAT_SCOPE` y
   `HARNESS_FEAT_TEST_CMD` (vacíos por defecto).
2. **`init.sh`** — flag `--fast` +分支 del paso 6. Verificar que sin flag
   el comportamiento es idéntico al actual.
3. **`run-mutation.sh`** — resolver scope → `--test-cmd`.
4. **Validar manualmente:** poblar `HARNESS_FEAT_SCOPE` con un test file,
   correr `bash harness-kit/tools/run-mutation.sh responder/panel.py` y
   medir tiempo vs. sin scope. Confirmar que el score es el mismo (los
   tests que muerden no cambian; solo se corre subconjunto).
5. **Agentes:** actualizar `tdd_craftsman` (poblar scope, usar
   `FEAT_TEST_CMD` en loop) y `mutation_tester` (setear scope antes de
   mutar) en `.opencode/agents/` y `.claude/agents/`.
6. **`judge`** — usar `./init.sh --fast` en su verificación intermedia.
7. **Docs:** `docs/verification.md` — documentar el modelo de 2 gates
   (desarrollo = fast/scope; producción = suite completa en `Stop` hook).
8. **No tocar `Stop` hook ni `PostToolUse` hook** — son el gate de
   producción y el loop rápido existente, ya correctos.

Cada paso es independiente y reversible (las variables vacías caen al
comportamiento actual).

---

## 7. Lo que NO cambia

- La suite completa (`HARNESS_TEST_CMD`) se sigue corriendo **antes de
  producción** (Stop hook / `init.sh` sin flag).
- El umbral de mutación sigue siendo 100% (`HARNESS_MUTATION_THRESHOLD`).
- Las Tres Leyes del TDD (un test a la vez) no se relajan.
- La aprobación humana de los `.feature` no se toca.
- El contrato de 4 líneas de los subagentes no cambia.

La única diferencia: **corremos la suite completa muchas menos veces
durante el desarrollo, y exactamente las mismas veces en los gates
reales.**

---

## Estado de implementación

> **IMPLEMENTADO (2026-07-02)** — ver `plan-implementacion-fixes.md`. Opción A
> (scope de feat completo), el modo por-archivo (§4.2) queda como opt-in futuro.
>
> - `harness.config.sh`: `HARNESS_FEAT_SCOPE` + `HARNESS_FEAT_TEST_CMD`
>   añadidos (vacíos por defecto = cero regresión).
> - `tools/run-mutation.sh`: resuelve el scope → `--test-cmd` del mutador.
> - `init.sh`: flag `--fast` (paso 6 bifurca: scope / warn-skip / suite completa).
> - Agentes (`tdd_craftsman`, `mutation_tester`, `judge`) en `.opencode/` y
>   `.claude/`: poblar/usar scope, `--progress-file`, `--fast` en review.
> - `docs/verification.md`: sección "Modelo de 2 gates" documentada.
> - `Stop` hook y `PostToolUse` hook: intactos (gate de producción + loop rápido).
> - Aplicado al kit (template) y al downstream `responder_service/harness-kit`.
