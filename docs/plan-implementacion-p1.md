# Plan de implementación — Lote P1 (preparación de specs)

> Basado en `docs/plan-mejoras-spec-workflow.md` y en la lectura de la fuente
> canónica de gentle-ai (`internal/assets/claude/agents/sdd-{explore,propose,
> spec,design}.md` y `sdd-orchestrator.md`).
> Este documento es el **diseño exacto** del lote P1 para aprobación previa.
> Nada se edita hasta el visto bueno.

## Principio rector (lo que aprendimos de gentle-ai)

Las mejoras de gentle-ai son un **sistema productor/consumidor**, no ediciones
sueltas. El *Result Contract* solo aporta valor porque el orquestador lo
**consume** como gatekeeper (valida contrato + artefacto + no-drift antes de
avanzar). Por tanto:

- **P1.3 se implementa junto a un paso gatekeeper en `craftsman_lead`.** Si no,
  el contrato es decoración (el propio plan lo advierte: "ningún agente lo emite").
- **P1.1 y P1.2 son el mismo paso** en `sdd-propose`: el eje #9 de la taxonomía
  es "scope boundaries and non-goals". Se editan juntas en `spec_partner`.

### Adaptaciones a Uncle Bob (no copia literal)

1. **Contrato slim de 4 campos**, no los 6 de gentle-ai. `next_recommended` y
   `skill_resolution` sirven a su DAG-router y skill-registry, que no tenemos
   (pipeline lineal fijo). Adoptamos: `status`, `artifact`, `risks`, `next`.
2. **Sin toggle auto/interactive.** gentle-ai lo necesita por no tener puerta
   humana; nosotros ya la tenemos sobre el `.feature`. El gatekeeper de
   `craftsman_lead` es **mecánico y autónomo**; la aprobación **semántica**
   sigue siendo humana sobre el Gherkin.
3. **P3.8 (anti-drift) se pliega al gatekeeper**, no es artefacto nuevo.

### Alcance de archivos

Cada agente vive **dos veces**: raíz (`.claude/agents/`) y kit
(`craftsman-harness-kit/.claude/agents/`). Toda edición es doble. Aplicamos al
**kit** (lo que se distribuye) y reflejamos en el **ejemplo**.

---

## P1.1 + P1.2 — `spec_partner.md` (raíz + kit)

### Cambio 1 — sección "Mentalidad" → añadir taxonomía

Tras el bloque de preguntas existente, insertar:

```markdown
## Taxonomía de preguntas (cubre el subconjunto útil más pequeño)

No dispares las 10 de golpe. Elige las que de verdad reducen ambigüedad de
ESTA feature. Son preguntas de **producto/negocio**, no de mecánica del harness
(no preguntes por comandos de test, forma del PR ni presupuesto de líneas salvo
que el humano quiera hablar de entrega):

1. **Problema de negocio** — qué dolor/oportunidad lo hace valer la pena ahora.
2. **Usuarios y situación** — quién, en qué flujo, en qué momento, con qué urgencia.
3. **Reglas de negocio** — políticas, permisos, umbrales, invariantes del dominio.
4. **Resultado esperado** — qué debe sentirse/funcionar/volverse posible después.
5. **Gap actual** — qué está mal, inconsistente o ausente hoy.
6. **Implicaciones e impacto** — qué flujos, datos, UX o soporte se ven afectados.
7. **Casos límite** — vacíos, datos parciales, fallos, permisos, estados raros.
8. **Gaps de decisión** — qué incógnitas harían la spec ambigua o fácil de sobre-construir.
9. **Límites de alcance y NO-goals** — qué entra en el primer corte, qué es
   refinamiento posterior y qué **no se toca aunque esté relacionado**.
10. **Riesgo/tradeoff** — qué downside importa más si elegimos mal la dirección.

### Protocolo de ronda

- 3–5 preguntas concretas por ronda. Una ronda, no un cuestionario infinito.
- Al recibir respuestas: **resume los supuestos resultantes** y ofrece corregir
  algo o lanzar una segunda ronda.
- Si no puedes preguntar directamente, escribe una sección
  `## Ronda de preguntas` en `project-spec.md` con las preguntas y los supuestos
  que necesitan validación humana.
```

### Cambio 2 — paso 4 del Protocolo: añadir "Fuera de alcance"

En la lista de la sección por feature (líneas ~47-52), añadir un ítem:

```markdown
   - **Fuera de alcance** — qué NO hace esta feature y qué queda para después
     (no-goals explícitos). Si algo relacionado **no se toca**, dilo aquí.
```

### Cambio 3 — `feature_list.json`: campo `out_of_scope` (opcional)

Documentar (no forzar en features existentes) que una feature `"sdd": true`
puede llevar:

```json
"out_of_scope": ["lo que esta feature explícitamente NO hace"]
```

> Decisión a confirmar: ¿añadimos `out_of_scope` también a las features ya
> `done`, o solo a partir de las `pending`? Recomendado: solo `pending`+nuevas.

---

## P1.3 — Result Contract slim (los 6 agentes) + Gatekeeper (`craftsman_lead`)

### Cambio 4 — contrato en la sección "Comunicación" de cada agente

Hoy cada agente emite un one-liner con status implícito
(`green`/`blocked`, `APPROVED`/`CHANGES_REQUESTED`, `PASS`/`FAIL`). Lo
elevamos a un bloque fijo de 4 campos **sin romper** el token de status que el
lead ya reconoce:

```markdown
## Comunicación

Tu salida final es este bloque de 4 líneas (nada más; el contenido vive en disco):

​```
status: done | blocked | partial
artifact: <ruta al archivo>
risks: <una línea, o "-">
next: <recomendación para el lead, o "-">
​```
```

Mapeo por agente (qué va en `status`):

| Agente            | `done` cuando…            | `blocked`/`partial` cuando…              | `artifact`                       |
|-------------------|---------------------------|------------------------------------------|----------------------------------|
| `spec_partner`    | spec actualizado          | quedan PREGUNTAS ABIERTAS sin cerrar     | `project-spec.md (#id name)`     |
| `gherkin_author`  | `.feature` destilado      | spec insuficiente para destilar          | `features/<name>.feature`        |
| `tdd_craftsman`   | verde + refactor          | no puede avanzar (`blocked` actual)      | `progress/tdd_<name>.md`         |
| `judge`           | APPROVED                  | CHANGES_REQUESTED → `partial`            | `progress/judge_<name>.md`       |
| `mutation_tester` | PASS sobre umbral         | FAIL bajo umbral → `partial`             | `progress/mutation_<name>.md`    |

> El status léxico previo (APPROVED, PASS…) se mantiene **dentro** del archivo
> de progreso; el campo `status` del bloque lo normaliza para el gatekeeper.

### Cambio 5 — sección "Gatekeeper" nueva en `craftsman_lead.md`

Insertar antes de "Qué NO haces":

```markdown
## Gatekeeper (consumes el contrato de cada fase)

Tras CADA subagente, antes de lanzar el siguiente, valida su bloque de salida.
Esto es validación **mecánica y autónoma** (no es la puerta humana, que sigue
siendo sobre el `.feature`):

1. **Conformidad**: llegaron los 4 campos y `status` no es vacío.
2. **Existencia del artefacto**: el `artifact` declarado existe y es legible
   (léelo de disco). Un status `done` sin artefacto recuperable **FALLA**.
3. **No-drift** (anti-P3.8): `acceptance[]` de `feature_list.json`,
   `project-spec.md` y `features/<name>.feature` no se contradicen. Requisitos
   inventados, scope creep o requisitos caídos **FALLAN**.
4. **Coherencia de cierre**: nunca avances a `done` sin `judge=done` Y
   `mutation_tester=done`.

**Reacción por status:**
- `done` + checks OK → avanza a la siguiente fase.
- `partial` → la fase no llegó al objetivo (p. ej. `judge` pidió cambios,
  mutación bajo umbral). Re-lanza la MISMA fase una vez con feedback concreto
  citando qué faltó. Si vuelve `partial`, **para** y reporta al humano.
- `blocked` → para de inmediato. Reporta al humano qué bloquea (de `risks`) y
  marca la feature `blocked` en `feature_list.json`.

No marcas tú `done` (eso es del `tdd_craftsman`), pero **sí** puedes y debes
marcar `blocked`.
```

### Cambio 6 — reflejar el gatekeeper en `CLAUDE.md` (raíz + kit)

Añadir una viñeta en "Reglas duras" apuntando a la nueva sección, para que el
rol obligatorio lo incluya desde el arranque.

---

## Orden de ejecución del lote

1. Cambios 1–3 (`spec_partner` + doc de `feature_list`) — riesgo casi nulo.
2. Cambios 4–6 (contrato + gatekeeper) — la columna vertebral.
3. Verificación: `./init.sh` sigue en verde; ningún cambio toca `src/`/`tests/`.

## Fuera de este lote (P2/P3, según re-priorización)

- **P2.5** design-note ADR opcional gateada por complejidad.
- **P2.4** exploración previa plegada en `spec_partner` + `Explore` nativos.
- **P2.6** config máquina: **bajada de prioridad** (nuestro dolor es kit↔ejemplo,
  no prosa dispersa; sin hook consumidor no aporta).
- **P3.7** trazabilidad: emergente del gatekeeper; matriz solo si se pide.

## Decisiones abiertas para el humano

- [ ] `out_of_scope` ¿solo en `pending`+nuevas, o retroactivo a `done`?
- [ ] Contrato slim de 4 campos: ¿OK, o quieres conservar `next_recommended`
      pese a que el pipeline es lineal?
- [ ] ¿Editamos ejemplo y kit en el mismo PR, o kit primero y ejemplo después?
