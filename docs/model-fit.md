# Model-fit — qué modelo conviene a cada fase (matriz congelada + banco A/B)

> Congela la investigación de `docs/plan-p2-modelos-por-fase.md` como referencia
> operativa: la matriz **fase → exigencia → tier → modelo**, el **método de
> medición A/B** y los **criterios de decisión** para promover o abandonar
> proveedores externos (Codex, OpenCode Go).
> Estado: **referencia viva**. La asignación efectiva la consume el
> `craftsman_lead` desde `model-map.yaml` (Lote 2).

## 1. Principio: doble indirección `fase → tier → modelo`

No se mapea fase → modelo directo (frágil al cambiar de proveedor). En su lugar:

1. Cada fase tiene un **tier semántico** (capacidad requerida), agnóstico de
   proveedor: `deep` / `standard` / `cheap`.
2. Un **perfil de proveedor activo** resuelve `tier → modelo concreto`.
3. Cambiar de proveedor = cambiar una variable; el mapa fase→tier no se toca.

## 2. Restricción de arquitectura (leer antes que nada)

El harness corre sobre la herramienta `Agent` de **Claude Code**, cuyo parámetro
`model:` **solo acepta IDs de Claude** (`opus`/`sonnet`/`haiku`/`fable`). Por eso:

- **No** se puede hacer que un subagente de Claude Code corra en un modelo de
  OpenCode ni en Codex sin un puente.
- **Ruta A (hoy):** modelo por fase **solo Claude** vía `Agent(model=)`. Captura
  el grueso del ahorro sin tocar la orquestación. → Lote 2.
- **Ruta C (piloto):** `craftsman_lead` hace **shell-out** a `codex exec` para
  una fase concreta (loop TDD). → Lote 6, medido.
- **Ruta B (futuro):** portar la orquestación a OpenCode Go (multi-proveedor
  real). → Lote 7, solo si C valida los externos.

## 3. Matriz fase → exigencia → tier → modelo

IDs y precios verificados (skill `claude-api`, junio 2026), $/MTok in·out:
`claude-opus-4-8` 5·25 · `claude-sonnet-4-6` 3·15 · `claude-haiku-4-5` 1·5 ·
`claude-fable-5` 10·50 (reservado, no usado por defecto — sin tier `max`).

| Fase | Qué exige de verdad | Tier | Claude (activo) | Candidato externo | Veredicto honesto |
|------|---------------------|------|-----------------|-------------------|-------------------|
| `harness_bootstrap` | Detección de stack, mecánico | cheap | Haiku 4.5 | Qwen3 / DeepSeek | Casi un script. No invertir aquí. |
| `spec_partner` | Debate de producto, pushback, elicitación | **deep** | **Opus 4.8** | GLM/Qwen flojos en debate adversarial | **Claude deep. No abaratar.** Aquí la calidad compone. |
| `gherkin_author` | Destilación estructurada spec→Gherkin | standard | Sonnet 4.6 | **Qwen3-Coder / GLM-5.2 buenos** | Sonnet base; viable externo si el coste manda. |
| `tdd_craftsman` | TDD estricto, code+tests, loop largo | standard | Sonnet 4.6 (Opus si difícil) | Codex GPT-5.x (agentic largo) | Sonnet base; piloto Codex. Externos "seguros" por los gates. |
| `judge` | Review adversarial — "el review es el juego entero" | **deep** | **Opus 4.8** | **No confiable** como gate final | **Claude deep. Nunca abaratar.** |
| `mutation_tester` | Corre `tools/mutate.py` y reporta vs umbral | cheap | Haiku 4.5 | Cualquiera | Apenas necesita LLM. |
| cierre / archive | Flip de estado + mover resumen | cheap | lo hace el lead (R1) | — | Mecánico, sin subagente. |
| `Explore` (nativo) | Barrido de lectura | cheap | Haiku | Externos ok | Haiku. |

## 4. Conclusiones honestas (las que importan)

1. **Los gates son red de seguridad** que hace **seguro** probar modelos
   baratos/externos en `gherkin` y `tdd`: si el barato se equivoca, el `judge`
   lo rechaza y la mutación lo detecta. El riesgo de abaratar esas dos fases es
   **bajo**, no alto.
2. **`spec_partner` y `judge` son donde la calidad compone** → Claude deep
   (Opus 4.8). Abaratarlos contamina todo lo aguas abajo; es el peor ahorro.
3. **Codex tiene UNA ventaja diferenciada y solo una**: el loop de
   implementación agentic largo. **Riesgo real**: su autonomía choca con "un
   test a la vez / Tres Leyes del TDD". Hay que **medir adherencia**, no
   asumirla. Por eso es piloto, no default.
4. **OpenCode no es un modelo**: es la capa de orquestación que habilita
   multi-proveedor (Ruta B). Sus modelos de pago encajan en
   `gherkin`/`tdd`/`mutación`/`bootstrap`, **no** en `judge`.

## 5. Banco de pruebas: cómo medir A/B contra baseline

**Baseline** = `docs/comparacion-flujo-p1.md` (feature #9 `cli_export`, 10
escenarios): **~275k tokens / ~15 min** de subagentes. Tres costes a batir:
~36% fue *resume* mecánico (R1), TDD es latencia del LLM, todo corrió en Opus.

### Protocolo

1. Elegir una feature cuyo **spec salga `done` a la primera** (sin `partial`),
   para aislar el coste base sin el re-run que infló la baseline.
2. Recorrer el pipeline completo con los lotes aplicados.
3. Capturar por fase, desde la telemetría del harness
   (`subagent_tokens` / `tool_uses` / `duration_ms`):

   | Métrica | Unidad | Fuente |
   |---------|--------|--------|
   | Tokens in/out | MTok | `subagent_tokens` por fase |
   | Coste | $ | tokens × precio del modelo resuelto |
   | Tiempo | s | `duration_ms` wall-clock por fase |
   | Tool-uses | n | `tool_uses` por fase |
   | Modelo resuelto | id | log del `craftsman_lead` (fase→modelo) |

4. Registrar la corrida como una fila nueva en la tabla de la §7.

### Qué esperar

- Tras **Lote 1+2**: tokens totales ↓ ~30% y **coste ↓ bastante más** por el
  cambio de modelo (gherkin/tdd/mutación/cierre fuera de Opus).
- Para **Lotes 6/7**: además de coste, **adherencia a TDD** y **paso de gates**
  como criterios de promoción (ver §6).

## 6. Criterios de decisión (promover / abandonar externos)

Un proveedor externo (Codex en `tdd`, OpenCode en `gherkin`/`tdd`/`mutación`)
**se promueve** a default de su fase solo si cumple **todo**:

- ✅ **Paso de gates**: la feature piloto pasa `judge` (APPROVED) y mutación
  ≥ umbral **igual** que con Claude. Un fallo de gate = no promover.
- ✅ **Adherencia a la disciplina** (solo `tdd`): respeta "un test a la vez" y
  las Tres Leyes; no escribe producción de más antes del test rojo. Se evalúa
  leyendo `progress/tdd_<name>.md` (mapa @s→test) y el orden de commits/edits.
- ✅ **Coste/tiempo real ≤ Claude** del mismo tier, **incluida** la fricción del
  puente (shell-out, envoltura del contrato de 4 campos).

**Se abandona** (y está bien que así sea) si: falla un gate, intenta hacer de
más en TDD, o el coste con puente no compensa frente a Sonnet/Haiku. La decisión
es por **datos** de la §7, no por fe.

## 7. Registro de corridas (A/B)

> Una fila por recorrido medido. La primera fila a llenar es la baseline P1 ya
> medida; las siguientes, tras cada lote.

| Fecha | Feature | Lotes aplicados | Perfil/modelos | Tokens tot | Coste aprox | Tiempo | Gates (judge/mut) | Adherencia TDD | Notas |
|-------|---------|-----------------|----------------|------------|-------------|--------|-------------------|----------------|-------|
| 2026-06-24 | #9 cli_export | ninguno (baseline P1) | anthropic, todo Opus | ~275k | — | ~15 min | APPROVED / 100% | n/a (Opus) | `docs/comparacion-flujo-p1.md` |

## 8. Relación con los lotes

- **Lote 0** (este doc): congela matriz + método + criterios.
- **Lote 2**: `model-map.yaml` consume la columna "Claude (activo)" de la §3.
- **Lote 6**: piloto Codex en `tdd`; promover/abandonar por §6.
- **Lote 7**: OpenCode Go; perfil `opencode_zen` con la columna "candidato externo".
