# Plan P2 — Rendimiento + investigación de modelos por fase (en lotes)

> Extiende `docs/plan-p2-rendimiento.md` (propuesta R1–R5) con una **investigación
> honesta de qué modelo conviene a cada fase** del workflow Uncle Bob, para tres
> mundos: **Claude** (Agent tool), **OpenCode Go** (suscripción de pago) y
> **Codex** (GPT-5.x CLI). Entrega por **lotes**, base primero y multi-proveedor
> después, con criterios de decisión.
> Estado: **en curso** — Lotes 0, 1 y 2 implementados; Lotes 2bis y 6 en curso; 3–5, 7 pendientes.
> (Lote 2 cerrado 2026-06-26: `model-map.yaml` en raíz + kit, bloque
> «Resolución de modelo» en `craftsman_lead.md`, bullet en ambos `CLAUDE.md`.)
> (Lote 2bis 2026-06-30: perfil `opencode_go` en `model-map.yaml`,
> `.opencode/agents/` con 3 definiciones, `tools/run-opencode.sh` wrapper,
> bloque híbrido en `craftsman_lead.md`.)
> (Lote 6 — piloto híbrido: implementado como modo híbrido en vez de Codex.)

## Contexto

La medición de la feature #9 (`docs/comparacion-flujo-p1.md`) dio **~275k
tokens / ~15 min** para una feature de 10 escenarios. Tres causas de coste:
(1) ~36% fue *resume* de agentes caros para trabajo trivial, (2) el TDD es
latencia del LLM (492 s / 75 tool-uses), (3) **ningún agente declara `model:`**
→ todo corre en el mismo modelo (Opus). El objetivo es bajar coste y latencia
**sin tocar las garantías** (puerta humana, judge, mutación, gatekeeper P1).

El usuario pidió, además, **investigar qué modelos cumplen bien cada fase** y
ser **totalmente sincero**. Esa investigación es el centro de este documento.

---

## Hallazgo crítico de arquitectura (leer antes que nada)

El harness corre sobre la herramienta `Agent` de **Claude Code**, cuyo parámetro
`model:` **solo acepta IDs de Claude** (opus/sonnet/haiku/fable). Consecuencias
honestas:

- **No se puede** hacer que un subagente de Claude Code corra en un modelo de
  OpenCode ni en Codex. El R2 “spec en Opus, TDD en modelo local” **no es un
  cambio de variable**: exige una de estas rutas.
- **Ruta A (barata, ya):** modelo por fase **solo Claude** vía `Agent(model=)`.
  Captura la mayor parte del ahorro de coste (Sonnet ≈ 1/1.7 de Opus en input;
  Haiku ≈ 1/5) sin tocar la orquestación.
- **Ruta C (piloto):** `craftsman_lead` hace **shell-out** a `codex exec` para
  una fase concreta (el loop TDD). Posible, pero frágil: pierde parte de la
  integración del contrato de 4 campos y del gatekeeper; hay que recablearla.
- **Ruta B (grande):** **portar la orquestación a OpenCode (Go)**, que sí es
  multi-proveedor. Máxima flexibilidad y ahorro; mucho mayor esfuerzo.

Decisión tomada: **las tres, en fases** (A ya, C piloto, B futuro).
Disponible hoy: **Codex CLI (GPT-5.x)** y **OpenCode Go (suscripción de pago →
modelos curados Zen/Go en nube: Qwen3-Coder, GLM-5.2, Kimi K2, Grok, DeepSeek)**.
No hay Ollama local → el perfil no-Claude apunta a nube de pago, no a local.

---

## Investigación: matriz fase → exigencia → modelo (evaluación honesta)

IDs y precios verificados (skill `claude-api`, junio 2026), $/MTok in·out:
`claude-fable-5` 10·50 · `claude-opus-4-8` 5·25 · `claude-sonnet-4-6` 3·15 ·
`claude-haiku-4-5` 1·5.

| Fase | Qué exige de verdad | Tier | Claude (recom.) | OpenCode Go/Zen (pago) | Codex (GPT-5.x) | Veredicto honesto |
|------|---------------------|------|-----------------|------------------------|-----------------|-------------------|
| `harness_bootstrap` | Detección de stack, mecánico | cheap | Haiku 4.5 | Qwen3 / DeepSeek: sobra | Overkill | Haiku (casi un script). No invertir aquí. |
| `spec_partner` | Debate de producto, pushback, elicitación | **deep** | **Opus 4.8** (Fable 5 si alto riesgo) | GLM/Qwen **flojos** en debate adversarial; Kimi razonable | Capaz, pero orientado a ejecución; pushback de producto menos calibrado que Opus | **Claude deep. No abaratar.** Aquí la calidad compone. |
| `gherkin_author` | Destilación estructurada spec→Gherkin | standard | Sonnet 4.6 | **Qwen3-Coder / GLM-5.2 buenos** (siguen formato) — mejor candidato a abaratar | Capaz, no diferenciado | Sonnet 4.6 base; **viable externo** si el coste manda. |
| `tdd_craftsman` | TDD estricto, code+tests, loop largo (60k tok / 492 s) | standard | Sonnet 4.6 (Opus en feature difícil) | Qwen3-Coder 32B decente en features simples | **Única ventaja real de Codex**: agentic coding de horizonte largo, auto-verificación | Sonnet base; **piloto Codex** (ver riesgo). Externos “seguros” por los gates. |
| `judge` | Review adversarial — “el review es el juego entero” | **deep** | **Opus 4.8** (Fable 5 si crítico) | **No confiable** como gate final | Decente pero no es el árbitro | **Claude deep. Nunca abaratar.** Opus 4.7+ mejora caza de bugs. |
| `mutation_tester` | Corre `tools/mutate.py` y reporta vs umbral | cheap | Haiku 4.5 | Cualquiera | Overkill | Haiku (apenas necesita LLM). |
| cierre / archive | Flip de estado + mover resumen | cheap | Haiku / lo hace el lead | Cualquiera | Overkill | Lead mecánico (R1). |
| `Explore` (nativo) | Barrido de lectura | cheap/std | Haiku / Sonnet | Externos ok | Ok | Haiku. |

### Conclusiones honestas (las que importan)

1. **Los gates son una red de seguridad** que hace **seguro** probar modelos
   baratos/externos en `gherkin` y `tdd`: si el modelo barato se equivoca, el
   `judge` lo rechaza y la mutación lo detecta. Por eso el riesgo de abaratar
   esas dos fases es **bajo**, no alto.
2. **`spec_partner` y `judge` son donde la calidad compone** → Claude deep
   (Opus 4.8). Abaratarlos contamina todo lo aguas abajo; es el peor ahorro.
3. **Codex tiene UNA ventaja diferenciada y solo una**: el loop de
   implementación agentic largo. **Riesgo real**: su autonomía choca con la
   disciplina “un test a la vez / Tres Leyes del TDD” — puede intentar hacer de
   más. Hay que **medir adherencia**, no asumirla. Por eso es piloto, no default.
4. **OpenCode no es un modelo**: es la **capa de orquestación** que habilita
   multi-proveedor. Su valor aquí es ser la Ruta B. Sus modelos de pago (Qwen3,
   GLM-5.2, Kimi) encajan en `gherkin`/`tdd`/`mutación`/`bootstrap`, **no** en
   `judge`.
5. **Coste**: mover `gherkin + tdd + mutación + cierre` fuera de Opus baja el
   coste sustancialmente ya con Ruta A. Con externos (Codex/Zen) el cálculo
   cambia por precio de tokens de terceros + fricción del puente; medir antes de
   creer que sale más barato.

---

## Lotes

### Lote 0 — Formalizar la investigación y el banco de pruebas
- **Qué:** congelar la matriz anterior como `docs/model-fit.md`; definir el
  método de medición A/B (tokens·tiempo·tool-uses por fase) y los **criterios de
  decisión** para promover/abandonar Codex y OpenCode.
- **Por qué:** “totalmente sincero” exige medir, no opinar. Sin banco, las Rutas
  C/B se deciden por fe.
- **Archivos:** `docs/model-fit.md` (nuevo), referencia desde
  `docs/plan-p2-rendimiento.md`.
- **Criterio de éxito:** una feature de baseline reproducible (spec `done` a la
  primera, sin re-run) contra la cual comparar.

### Lote 1 — R1: no reanudar agentes caros para trabajo trivial
- **Qué:** (a) el **cierre** lo hace el `craftsman_lead` tras verificar
  `judge=done` **y** `mutation_tester=done` (flip de `status: done` + mover
  resumen a `progress/history.md`), en vez de re-run del `tdd_craftsman`;
  (b) decisiones de una línea que el humano ya resolvió → el lead aplica el edit
  al spec directamente (es docs, permitido), sin reanudar `spec_partner`.
- **Por qué:** ~99k tokens (~36%) de la medición fueron *resume* mecánico.
- **Archivos:** acotar la regla dura en `CLAUDE.md` y
  `.claude/agents/craftsman_lead.md` (“no marques `done` **antes** de ambos
  gates”), y añadir el paso de cierre a la sección Gatekeeper (líneas ~95–130).
  Alternativa conservadora: *closer* fresco en Haiku, nunca un resume del
  transcript de implementación.
- **Decisión abierta:** lead-cierra vs closer-Haiku → ver Decisiones.

### Lote 2 — R2-A: modelo por fase, perfil **solo Claude** (la base)
- **Qué:** doble indirección **fase → tier → modelo** en un `model-map.yaml`
  junto a `harness.config.sh`; el `craftsman_lead` lo lee 1× por sesión, cachea
  `fase→modelo` y pasa `model:` en cada llamada a `Agent`.
- **Mapa (perfil `anthropic`):**
  - `deep` → `claude-opus-4-8` · `standard` → `claude-sonnet-4-6` · `cheap` → `claude-haiku-4-5`.
  - `spec_partner`=deep · `judge`=deep · `gherkin_author`=standard ·
    `tdd_craftsman`=standard · `mutation_tester`=cheap · `bootstrap`=cheap ·
    cierre=cheap · `Explore`=cheap.
- **Degradación:** si el modelo asignado no está disponible, degradar dentro del
  proveedor (`deep→standard→cheap`) y **registrarlo**, no fallar en silencio.
- **Por qué:** captura el grueso del ahorro sin tocar la orquestación. Es lo
  único de R2 realizable hoy dentro de Claude Code.
- **Archivos:** `model-map.yaml` (nuevo, kit + raíz), bloque “Resolución de
  modelo” en `craftsman_lead.md`, bullet en `CLAUDE.md`.
- **No incluye:** `phase_overrides` multi-proveedor (eso es Ruta B/Lote 7), pero
  el esquema **deja el hueco** (`phase_overrides:` documentado, sin consumir).
- **Decisión abierta:** ¿tier opcional `max` = `claude-fable-5` para features de
  alto riesgo, a pedido explícito? → ver Decisiones.

### Lote 3 — R3: test único en el loop TDD
- **Qué:** rellenar `HARNESS_TEST_ONE_CMD` (hoy `TODO`) y `HARNESS_TEST_FILE_PATTERNS`;
  el hook `PostToolUse` ya llama a `tools/test-affected.sh`, que cae a suite
  completa si el comando está vacío/`TODO`. La suite completa sigue como gate en
  `Stop` (`init.sh`).
- **Por qué:** en `notes-cli` (suite 0,1 s) apenas mueve la aguja, pero en un
  repo real con suite lenta es la diferencia entre segundos y minutos por ciclo.
- **Archivos:** `craftsman-harness-kit/harness.config.sh` (+ raíz si aplica).

### Lote 4 — R4: pasar `git diff` al judge
- **Qué:** que el `craftsman_lead` pase `git diff` + el `.feature` al `judge` en
  vez de que éste relea docs + src + tests (44,8k tokens medidos).
- **Por qué:** ~10–20k tokens menos por review, sin tocar la dureza del review.
- **Archivos:** prompt de lanzamiento del judge en `craftsman_lead.md`;
  preámbulo de `judge.md`.

### Lote 5 — R5: adelgazar el preámbulo de lectura
- **Qué:** cada agente lee `AGENTS.md` + 3–4 docs al arrancar; consolidar en un
  `_shared/phase-common.md` compacto leído 1×, o pasar solo el extracto
  relevante por fase.
- **Por qué:** ~5–15k tokens por sesión.
- **Archivos:** protocolo de cada `.claude/agents/*.md`; `_shared/phase-common.md` (nuevo).

### Lote 6 — R2-C: piloto **Codex en el loop TDD** (opcional, medido)
- **Qué:** `craftsman_lead` hace **shell-out** a `codex exec` solo para
  `tdd_craftsman` en una feature de prueba; el resto sigue en Claude. Codex
  recibe el `.feature` aprobado + `harness.config.sh` (comando de test único) y
  debe respetar Rojo→Verde→Refactor.
- **Por qué:** es la única fase con ventaja diferenciada de Codex.
- **Riesgo a medir (criterio de promoción):** ¿respeta “un test a la vez”?
  ¿el `judge` y la mutación pasan igual? ¿coste/tiempo real vs Sonnet?
- **Honestidad:** el puente pierde el contrato de 4 campos y parte del
  gatekeeper; hay que envolver la salida de Codex en el formato
  `status/artifact/risks/next` manualmente. Si la adherencia a TDD es mala o el
  coste no compensa, **se abandona** — está bien que así sea.
- **Archivos:** `tools/run-codex-tdd.sh` (nuevo), bloque condicional en
  `craftsman_lead.md`, `progress/tdd_<name>.md` como artefacto.

### Lote 7 — R2-B: multi-proveedor real vía **OpenCode Go** (futuro)
- **Qué:** portar la orquestación a OpenCode para correr fases en proveedores
  distintos a la vez (Anthropic-opus para `spec`/`judge`; Qwen3/GLM de OpenCode
  Go para `gherkin`/`tdd`/`mutación`), con `phase_overrides` realmente
  consumido.
- **Por qué:** máxima flexibilidad y ahorro; **solo** si los Lotes 0/6 muestran
  que los externos rinden y el ahorro justifica la reescritura.
- **Honestidad:** duplica orquestador o exige adaptar agentes; es un proyecto,
  no un lote pequeño. Mantener **un solo mapa + perfiles** (no duplicar agentes
  por plataforma, como sí hace gentle-ai).
- **Archivos:** asset-dir OpenCode, perfil `opencode_zen` en `model-map.yaml`,
  port de los 6 agentes.

---

## Orden recomendado

1. **Lote 0** (banco) → **Lote 1** (R1) → **Lote 2** (R2-A Claude-only). Esto solo
   ya da el ahorro grande y bajo riesgo.
2. **Lote 3, 4, 5** (R3/R4/R5) en cualquier orden, independientes.
3. **Lote 6** (piloto Codex) cuando haya baseline; promover/abandonar por datos.
4. **Lote 7** (OpenCode) solo si 6 valida los externos.

## Cómo medir (A/B contra baseline)

Repetir el recorrido con una feature cuyo spec salga `done` a la primera (sin
`partial`), para aislar el coste base sin el re-run, y comparar
tokens / tiempo / tool-uses **por fase** contra `docs/comparacion-flujo-p1.md`.
Esperado tras Lotes 1+2: tokens totales ↓ ~30% y coste ↓ bastante más por el
cambio de modelo. Para Lotes 6/7: además **adherencia a TDD** y **paso de
gates** como criterios de promoción, no solo coste.

## Decisiones abiertas

- [x] R1 cierre: lo hace el `craftsman_lead` (regla dura acotada a “no antes de
      ambos gates”). — *resuelto 2026-06-25*
- [x] R2 formato: `model-map.yaml` nuevo (una sola fuente de verdad). — *resuelto 2026-06-25*
- [x] R2 tier `max` = `claude-fable-5`: **no** (solo deep/standard/cheap). — *resuelto 2026-06-25*
- [ ] Lote 6: ¿qué feature de prueba se usa para el piloto Codex?
- [ ] Lote 7: ¿se confirma OpenCode Go como destino, o se queda como nota de
      investigación según resultados del piloto?

## Archivos a tocar (resumen)

- Nuevos: `docs/model-fit.md`, `model-map.yaml` (kit + raíz),
  `_shared/phase-common.md`, `tools/run-codex-tdd.sh`,
  `.opencode/agents/gherkin_author.md`, `.opencode/agents/tdd_craftsman.md`,
  `.opencode/agents/mutation_tester.md`, `tools/run-opencode.sh`.
- Editados: `CLAUDE.md`, `.claude/agents/craftsman_lead.md`,
  `.claude/agents/judge.md`, los preámbulos de `.claude/agents/*.md`,
  `craftsman-harness-kit/harness.config.sh`,
  `docs/plan-p2-rendimiento.md` (enlazar la investigación),
  `AGENTS.md` (tabla y regla 6 del arranque).
- Sin tocar: garantías del flujo (puerta humana, judge, mutación, gatekeeper P1).

## Verificación

- Tras cada lote: `./init.sh` verde (suite completa) — gate de no-regresión.
- Lote 2: una sesión de prueba debe mostrar en el log el `model:` resuelto por
  fase y la degradación registrada si falta un modelo.
- Lote 3: editar un `src/*` y comprobar que el hook corre **solo** el test
  mapeado (no la suite).
- Lotes 6/7: la feature piloto debe pasar `judge` + mutación igual que con
  Claude; registrar tokens/tiempo/adherencia TDD en `docs/model-fit.md`.
