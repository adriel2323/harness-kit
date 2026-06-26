# Comparación de flujo — mejoras P1 vs. flujo anterior

> Mide el coste real (tokens, tiempo, tool-uses) de un recorrido completo del
> pipeline Uncle Bob **con** las mejoras P1 (taxonomía, fuera-de-alcance,
> contrato de 4 campos + gatekeeper) y lo contrasta con el flujo previo.
> Caso medido: **feature #9 `cli_export`** (10 escenarios), 2026-06-24.

## 1. Fuente de los datos y metodología

- Datos **medidos**: telemetría por subagente que emite el harness al terminar
  cada tarea (`subagent_tokens`, `tool_uses`, `duration_ms`).
- Datos **estimados**: la columna "flujo anterior" — no hay un A/B real; se
  reconstruye restando los costes específicos de P1 del recorrido medido.
- Muestra: **N = 1 feature**. No es un benchmark estadístico, es una radiografía
  de un recorrido representativo.

### Advertencias de lectura (importantes)

1. **Reanudaciones inflan tokens.** Dos invocaciones fueron *resume* del mismo
   subagente (recargan su transcript): `spec_partner #2` y el cierre de
   `tdd_craftsman`. Su conteo de tokens **no es comparable** con una corrida
   fresca: incluye releer contexto previo.
2. **El orquestador no está en la telemetría.** Los tokens del `craftsman_lead`
   (yo, incluidas las verificaciones del gatekeeper) **no** aparecen en
   `subagent_tokens`; se estiman aparte.
3. El tiempo es *wall-clock* por subagente, ejecutados en serie. No incluye la
   latencia humana en la puerta de aprobación (es tiempo de persona, no de cómputo).

## 2. Coste medido por fase (recorrido con P1)

| # | Fase | Tokens | Tool-uses | Tiempo |
|---|------|-------:|----------:|-------:|
| 1 | `spec_partner` (1ª corrida) | 27.488 | 9 | 83,5 s |
| 1b | `spec_partner` (re-run por `partial`) ⚠️resume | 36.349 | 9 | 46,3 s |
| 2 | `gherkin_author` | 25.351 | 10 | 51,6 s |
| 3 | `tdd_craftsman` (implementación) | 60.426 | 75 | 492,0 s |
| 4 | `judge` | 44.822 | 14 | 83,5 s |
| 5 | `mutation_tester` | 17.887 | 8 | 66,3 s |
| 6 | `tdd_craftsman` (cierre) ⚠️resume | 62.811 | 9 | 75,8 s |
| | **TOTAL subagentes** | **275.134** | **134** | **899,0 s (~15 min)** |

> A esto se suma el coste del orquestador (`craftsman_lead`): ~6 verificaciones
> de gatekeeper (Bash/Read) + lanzamientos. Estimado: **~15–25k tokens** no
> reflejados arriba. La puerta humana añadió 2 ediciones de contrato (sin coste
> de subagente).

## 3. Qué de eso es **coste nuevo** de P1 (el delta)

No todo el recorrido es "más caro que antes". El flujo Uncle Bob (spec → gherkin
→ puerta → TDD → judge → mutación → cierre) ya existía. Lo que P1 **añade**:

| Coste nuevo | Tokens | Tiempo | ¿Evitable? |
|-------------|-------:|-------:|------------|
| **Re-run de `spec_partner`** por `status: partial` (decisión de escaping) | ~36.300 | ~46 s | Es el sistema funcionando: el gatekeeper paró ante una decisión abierta |
| Ronda de taxonomía en `spec_partner` #1 (escribir preguntas + supuestos) | ~3–5k (incl. arriba) | ~pocos s | Marginal |
| Contrato de 4 líneas vs 1 línea × 6 hand-offs | <1k total | ~0 | Despreciable |
| Verificaciones de gatekeeper del orquestador (~6 Bash/Read) | ~10–20k (orquestador) | ~varios s | Es el control de calidad |
| **Delta P1 aproximado** | **~50k tokens (~+15–18%)** | **~50–60 s (~+6%)** | — |

El **cierre** (`tdd_craftsman` #2, 62.8k) **no** es coste de P1: en cualquier
flujo disciplinado el cierre va después de judge+mutación, así que es una
invocación separada inherente al pipeline (no algo que P1 introdujo).

## 4. Estimación del flujo anterior (mismo feature, sin P1)

| Concepto | Flujo anterior (est.) | Flujo con P1 (medido) |
|----------|----------------------:|----------------------:|
| Tokens subagentes | ~225k | 275k |
| Tiempo subagentes | ~14 min | ~15 min |
| Hand-off | 1 línea, status implícito | contrato 4 campos, status explícito |
| Decisión de escaping | resuelta con supuesto **invisible** | expuesta como `partial`, decidida por humano |
| Verificación entre fases | confianza en el one-liner | gatekeeper (artefacto + no-drift + suite) |

> El flujo anterior es **~15–18% más barato en tokens** en el camino feliz…
> *siempre que el supuesto invisible fuera correcto.* Si no lo era, el coste se
> dispara: re-spec + re-gherkin + re-TDD + re-judge + re-mutación de una feature
> ya implementada con el contrato equivocado.

## 5. El cálculo coste/beneficio

El coste nuevo de P1 (~+50k tokens, ~+1 min) compró:

1. **Un defecto de contrato cazado antes de codificar.** La decisión de escaping
   de Markdown se habría horneado en el `.feature` firmado en silencio. Detectarla
   en spec (~36k tokens) vs. detectarla tras implementar y testear los 10
   escenarios: el `tdd_craftsman` solo costó **60k tokens y 8 min**. Rehacer por
   un contrato mal firmado cuesta **mucho más** que el re-run que lo evitó.
2. **Deuda visible.** El `mutation_tester` reportó en `risks` 3 mutantes
   heredados → quedaron registrados como feature #13, no perdidos en un log.
3. **Cierre con garantías.** Ninguna fase avanzó sin que el gatekeeper validara
   que el artefacto existía y la suite estaba verde; `done` exigió judge **y**
   mutación.

**Regla práctica:** P1 cambia el perfil de coste de *"barato ahora, caro si el
supuesto falla"* a *"~15% más caro ahora, plano si el supuesto falla"*. Es un
seguro: se paga una prima fija a cambio de no pagar el siniestro del rework.

## 6. Tabla de mejoras (cualitativa)

| Momento | Flujo anterior | Flujo con P1 |
|---------|----------------|--------------|
| Conversación de spec (P1.1) | ~4 prompts ad-hoc | taxonomía de 10 ejes + ronda con supuestos |
| Alcance (P1.2) | implícito | sección **Fuera de alcance** explícita |
| Decisión abierta (P1.3) | `spec_updated ->` y a seguir | `partial` + `risks` → gatekeeper para → decisión humana |
| Cada hand-off | one-liner de confianza | contrato 4 campos validado (artefacto + no-drift + suite) |
| Puerta humana | sí | sí (capturó "1 notas" → contrato corregido antes de TDD) |
| Cierre | — | coherencia: no `done` sin judge **y** mutación |
| Mutación | PASS/FAIL | `risks` hace visible la deuda (3 mutantes heredados → #13) |

## 7. Conclusión

- **Sobrecoste medido del recorrido:** ~275k tokens / ~15 min de subagentes para
  una feature de 10 escenarios con TDD estricto + review + mutación.
- **Delta atribuible a P1:** ~+15–18% tokens, ~+6% tiempo, concentrado en el
  re-run que dispara el gatekeeper ante una decisión abierta.
- **Veredicto:** el sobrecoste es una prima de seguro razonable. El ahorro
  esperado (evitar rework de contrato + deuda no perdida) supera la prima en
  cuanto un solo supuesto invisible habría sido incorrecto — que es justo lo que
  pasó en este recorrido.

> Próximo paso de medición: repetir con una feature donde el spec salga `done` a
> la primera (sin `partial`) para aislar el coste base de P1 sin el re-run.
