# Plan P2 — Rendimiento (tokens y tiempo) para la próxima sesión

> Origen: medición real del recorrido completo de la feature #9 `cli_export`
> (ver `docs/comparacion-flujo-p1.md`). Este documento propone mejoras de
> **consumo y latencia** sin tocar las garantías del flujo Uncle Bob
> (puerta humana, judge, mutación, gatekeeper P1).
> Estado: **propuesta** — nada implementado todavía.

## Diagnóstico (de la medición)

Recorrido completo: **~275k tokens / ~15 min** de subagentes para una feature
de 10 escenarios. Hallazgos clave:

1. **~36% de los tokens (~99k) fue overhead de *resume*** para trabajo trivial:
   el cierre de `tdd_craftsman` (62.8k) y el re-run de `spec_partner` (36.3k)
   recargaron transcripts grandes para tareas mecánicas/de una línea.
2. **El tiempo de TDD (492s / 75 tool-uses ≈ 6,5s/paso) es latencia del LLM**,
   no ejecución de tests (la suite tarda 0,1s).
3. **Ningún agente declara `model:`** → todo corre en el mismo modelo (Opus).
   No hay asignación por fase.
4. El hook `PostToolUse` del ejemplo corre la **suite completa** en cada
   Edit/Write; no usa test único (el kit tiene `HARNESS_TEST_ONE_CMD` en TODO).

## Palancas (orden recomendado de implementación)

| # | Mejora | Ahorro estimado | Riesgo | Esfuerzo |
|---|--------|-----------------|--------|----------|
| **R1** | No reanudar agentes caros para trabajo trivial | ~80–100k tokens (~30%) | Bajo | Bajo |
| **R2** | **Modelo por fase adaptable (multi-proveedor)** | -40–60% en *coste* + menos latencia | Medio | Medio |
| **R3** | Test único en el loop TDD (no suite completa) | Tiempo TDD ↓ mucho **a escala** | Bajo | Bajo |
| **R4** | Pasar `git diff` al `judge` en vez de releer todo | ~10–20k tokens | Bajo | Medio |
| **R5** | Adelgazar el preámbulo de lectura de cada agente | ~5–15k tokens | Bajo | Medio |

---

## R1 — No reanudar agentes caros para trabajo trivial

**Problema:** reanudar (`SendMessage` a un agente existente) recarga su
transcript completo. Para tareas mecánicas eso es puro desperdicio.

**Dos cambios:**

1. **Cierre por el gatekeeper, no por re-run del `tdd_craftsman`.**
   Hoy el `tdd_craftsman` marca `done` (regla dura). Propuesta: una vez el
   gatekeeper verificó `judge=done` **y** `mutation_tester=done`, el
   `craftsman_lead` hace el flip mecánico de `status: done` + mueve el resumen a
   `progress/history.md`. Es post-gates-verificados, así que no relaja la
   disciplina. Alternativa conservadora: un *closer* fresco en modelo barato
   (Haiku), nunca un resume del transcript de implementación.
   - Tocar: regla dura en `CLAUDE.md`/`craftsman_lead.md` (acotar el "no marques
     done" a "no marques done **antes** de ambos gates"), y la sección
     Gatekeeper (añadir el paso de cierre).

2. **Decisiones de una línea sin re-run.** Cuando un agente vuelve `partial`
   por una decisión que el humano ya resolvió (p. ej. el escaping de #9), el
   `craftsman_lead` aplica el edit al spec directamente (es docs, permitido) en
   vez de reanudar al `spec_partner`.
   - Tocar: sección Gatekeeper de `craftsman_lead.md` (reacción a `partial`).

---

## R2 — Modelo por fase adaptable (lo que más interesa)

> Objetivo: asignar el modelo **por fase**, de forma que sea **intercambiable
> por proveedor** (Anthropic, OpenCode con modelos locales, Gemini, etc.) y
> sirva para orquestación **multi-agente** donde distintas fases corren en
> distintos proveedores/modelos.

### Principio: doble indirección `fase → tier → modelo`

No mapear fase → modelo directo (frágil al cambiar de proveedor). En su lugar:

1. Cada fase tiene un **tier semántico** (capacidad requerida), agnóstico de
   proveedor.
2. Un **perfil de proveedor activo** resuelve `tier → modelo concreto`.
3. Cambiar de proveedor = cambiar una variable; el mapa fase→tier no se toca.

### Tiers semánticos

- `deep` — máxima capacidad de razonamiento (decisiones de producto/diseño,
  review adversarial).
- `standard` — capacidad media, buen coste/latencia (destilación, implementación).
- `cheap` — tareas mecánicas (estado, copy, correr herramienta y reportar).

### Mapa fase → tier (harness Uncle Bob)

| Fase | Tier | Razón |
|------|------|-------|
| `harness_bootstrap` | `standard` | detección de stack, mecánico |
| `spec_partner` | `deep` | debate, decisiones de producto |
| `gherkin_author` | `standard` | destilación estructurada |
| `tdd_craftsman` | `standard` | implementación guiada por contrato; además más rápido |
| `judge` | `deep` | "el review es el juego entero" — no abaratar |
| `mutation_tester` | `cheap` | corre la herramienta + reporta |
| cierre / archive | `cheap` | estado + copy |
| `Explore` (nativo) | `cheap`/`standard` | barrido de lectura |

### Perfiles de proveedor (`tier → modelo`)

```yaml
active_profile: anthropic

profiles:
  anthropic:                       # IDs y precios verificados (claude-api skill)
    deep:     claude-opus-4-8      # $5 / $25 por MTok
    standard: claude-sonnet-4-6    # $3 / $15
    cheap:    claude-haiku-4-5     # $1 / $5
  opencode_local:                  # ejemplo; ajustar a los modelos instalados
    deep:     qwen2.5-coder:32b
    standard: qwen2.5-coder:14b
    cheap:    qwen2.5-coder:7b
  gemini:
    deep:     gemini-2.x-pro
    standard: gemini-flash
    cheap:    gemini-flash-lite
```

> Nota de coste (perfil anthropic): mover `gherkin_author`, `tdd_craftsman`,
> `mutation_tester` y el cierre fuera de Opus baja el coste por token de forma
> sustancial (Sonnet ≈ 1/1.7 de Opus en input; Haiku ≈ 1/5). `spec_partner` y
> `judge` se quedan en `deep` (no abaratar el juicio).

### Multi-agente / multi-proveedor en OpenCode

Para permitir que distintas fases corran en **distintos proveedores** a la vez
(p. ej. spec en Anthropic-opus, TDD en un modelo local), extender el esquema con
override por fase:

```yaml
# Opcional: gana sobre active_profile cuando está presente
phase_overrides:
  spec_partner:   { provider: anthropic,      tier: deep }
  judge:          { provider: anthropic,      tier: deep }
  tdd_craftsman:  { provider: opencode_local, tier: standard }
  mutation_tester:{ provider: opencode_local, tier: cheap }
```

Resolución: `phase_overrides[fase]` si existe → si no, `(active_profile, tier)`.
gentle-ai logra esto con un asset-dir por plataforma (claude/, opencode/, …)
**duplicando** el orquestador; nuestra adaptación lo hace con **un solo mapa +
perfiles**, sin duplicar agentes.

### Dónde vive y quién lo consume

- **Dónde:** un `model-map.yaml` junto a `harness.config.sh` (o un bloque dentro
  de él si se prefiere shell). Una sola fuente de verdad.
- **Consumidor:** el `craftsman_lead` lo lee una vez por sesión, cachea
  `fase → modelo`, y pasa `model: "<id>"` en cada llamada a la herramienta
  `Agent`. (En el harness Claude Code, `Agent` acepta `model`.)
- **Degradación/fallback:** si el modelo asignado no está disponible, degradar
  dentro del proveedor (`deep → standard → cheap`) o caer a un default seguro;
  registrarlo, no fallar en silencio. (Espejo del "If you lack access to the
  assigned model, substitute and continue" de gentle-ai.)

### Adaptaciones a Claude (de la referencia de la API)

- IDs exactos: `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5`
  (no añadir sufijos de fecha; Bedrock usa prefijo `anthropic.`, Vertex sin
  prefijo).
- `claude-fable-5` ($10/$50) NO es el default: reservarlo para un tier `max`
  opcional en trabajo de muy alto riesgo, a pedido explícito.

---

## R3 — Test único en el loop TDD

Rellenar `HARNESS_TEST_ONE_CMD` y que el hook `PostToolUse` corra **solo el test
del archivo editado**; la suite completa sigue siendo gate en `Stop`. En
`notes-cli` apenas mueve la aguja (suite de 0,1s), pero en un repo real con
suite lenta es la diferencia entre segundos y minutos por ciclo.
- Tocar: `harness.config.sh` (kit) + `settings.json` del ejemplo.

## R4 — Pasar diff al judge

El `judge` relee docs + src + tests (44.8k tokens en la medición). Que el
`craftsman_lead` le pase `git diff` + el `.feature` reduce relectura.
- Tocar: prompt de lanzamiento del judge en `craftsman_lead.md`.

## R5 — Adelgazar el preámbulo de lectura

Cada agente lee `AGENTS.md` + 3-4 docs al arrancar. Un `_shared/phase-common.md`
compacto leído una vez (patrón de gentle-ai) o pasar solo el extracto relevante.
- Tocar: protocolo de cada agente.

---

## Cómo medir el resultado (A/B contra la baseline)

Repetir el recorrido con una feature cuyo spec salga `done` a la primera (sin
`partial`) para aislar el coste base de P1 sin el re-run, y comparar tokens /
tiempo / tool-uses por fase contra `docs/comparacion-flujo-p1.md`. Esperado tras
R1+R2: tokens totales ↓ ~30% y coste ↓ bastante más por el cambio de modelo.

## Investigación de modelos por fase

La matriz fase → tier → modelo, el método de medición A/B y los criterios de
promoción/abandono de proveedores externos están congelados en
**`docs/model-fit.md`** (Lote 0 de `docs/plan-p2-modelos-por-fase.md`).

## Decisiones abiertas para la próxima sesión

- [x] R1 cierre: lo hace el `craftsman_lead` (regla dura acotada a "no antes de
      ambos gates"). — *resuelto 2026-06-25*
- [x] R2 formato: `model-map.yaml` nuevo (una sola fuente de verdad). — *resuelto 2026-06-25*
- [ ] R2 perfil local: ¿qué modelos de OpenCode hay instalados para rellenar
      `opencode_local`? (pendiente; Ruta B / Lote 7)
- [x] Tier `max` (`claude-fable-5`): **fuera por ahora** (solo deep/standard/cheap). — *resuelto 2026-06-25*
