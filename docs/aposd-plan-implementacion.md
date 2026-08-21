# Plan de implementación — APOSD en el Craftsman Harness

> Ejecuta el diseño de `docs/aposd-integracion.md`. Entrega **por lotes**, cada
> uno cerrable y reversible por separado.
> Estado: **lotes 0, 1, 2 y 3 hechos** (2026-08-10, sin commitear). Falta el 4,
> que espera rodaje real del 2.
>
> **Histórico desde el Lote 2.** La fuente de verdad del pipeline pasó a ser
> `docs/workflow.md` y los prompts de `.claude/agents/`. Este archivo queda como
> registro de las decisiones (C-1..C-3, D-1..D-4) y de los riesgos a vigilar.
>
> Regla de oro del plan: **los lotes 0, 1 y 3 entregan valor sin tocar el
> pipeline.** Si después de rodarlos decides no seguir, no queda nada roto ni a
> medio hacer.

## Índice de lotes

| Lote | Qué | Estado | Toca el pipeline | Reversible | Depende de |
|---|---|---|---|---|---|
| **0** | Base inerte: skill + `docs/design/` + propagación | ✅ hecho | No | Borrar archivos | — |
| **1** | Lente de red flags en el `judge` | ✅ hecho | No | Revertir 2 archivos | 0 |
| **2** | La fase `design_partner` + modo apagable + interfaz congelada | ✅ hecho | **Sí** | Sí (ver §2.9) | 0 |
| **3** | Auditoría de complejidad para legacy | ✅ hecho | No | Borrar archivos | 0 |
| **4** | DDR-000 de esqueleto en el bootstrap | ⏳ pendiente | No | Revertir 1 archivo | 2 |

Orden recomendado: **0 → 1 → medir → 2 → 3**. En la práctica se hizo
0 → 1 → 3 → 2. El 4 solo después de que el 2 tenga rodaje real.

> **Hallazgo del Lote 2:** el check de divergencia de D-4 encontró, en su primera
> corrida, drift **más allá** del `tdd_craftsman` que C-2 había mapeado: el
> espejo `.opencode/agents/mutation_tester.md` no tenía el formato del veredicto,
> las reglas duras ni la regla de **exit 3** — o sea que en perfil `opencode_go`
> el gate de mutación **podía reportar PASS con evidencia truncada**. Portado en
> el mismo lote. Es la justificación empírica del check: el drift no era un caso,
> era una clase.

> **Hallazgo del Lote 1, que no era de este plan:** ningún agente del kit tiene la
> tool `Skill` en su `tools:`, así que `threat-lens` **no funcionaba** desde el
> commit `5125a43` — `judge.md` y `gherkin_author.md` decían «invoca la skill» sin
> tener con qué. Corregido: los tres pasos leen el SKILL.md por ruta con `Read`,
> que es lo que el espejo opencode ya hacía bien. Detalle en el HISTORIAL.

---

## Tres correcciones al informe, antes de empezar

Al verificar los puntos de inserción aparecieron tres cosas que cambian el plan
respecto de `docs/aposd-integracion.md`.

### C-1. No se añade el estado `design_ready`

El informe dibujaba `[design_ready]` en el pipeline. **Sacarlo.** Añadir un
estado cuesta tocar `feature_list.json` (`rules.valid_status`), los **tres**
validadores de `init.sh:71-129`, `CHECKPOINTS.md` C2 y la tabla de `AGENTS.md` —
y no compra nada: el Gatekeeper ya verifica fases por **existencia del artefacto
en disco** (`craftsman_lead.md:225-226`), no por estado.

El `design_partner` corre dentro de `spec_ready`. Su artefacto es el DDR. Elimina
cinco enganches.

### C-2. El espejo opencode ya está desincronizado

`.opencode/agents/tdd_craftsman.md` **no tiene** lo que su gemelo Claude sí:

| Falta en el espejo opencode | Está en |
|---|---|
| Cabecera `covers:` (mapa durable módulo→tests) | `.claude/agents/tdd_craftsman.md:64-71` |
| Sección «Modo refactor (`[REFACTOR]`)» completa | `:39-50` |
| Sección «Reglas duras» completa | `:95-105` |
| Pre-condiciones | `:33-37` |

O sea: **si hoy corres el perfil `opencode_go`, el `tdd_craftsman` no escribe la
cabecera `covers:`** — y de ella dependen `tools/test-map.sh`, el scope de la
mutación y la validación del `judge` (`judge.md:33-38`). Es un bug preexistente,
no lo introduce APOSD.

No hay ningún check que detecte la divergencia. **Recomendación: arreglarlo en el
Lote 2** (que ya toca ese archivo) y añadir el check, o el drift se va a
ensanchar con cada cambio.

### C-3. Cada regla de validación nueva cuesta 3×

`init.sh:71-129` tiene el validador **triplicado**: Python, Node y un fallback de
`grep`. Es red flag #7 (repetición) preexistente. Consecuencias para este plan:
toda validación nueva se escribe tres veces, y el fallback de `grep` **no puede**
validar nada estructural. Es un argumento fuerte para añadir el mínimo posible de
validación (ver C-1).

---

## LOTE 0 — Base inerte

**Objetivo:** que la skill exista y se propague, sin que nadie la invoque todavía.

### 0.1 Copiar y aterrizar la skill

```
.claude/skills/aposd-design/
├── SKILL.md                    ← + sección de precedencia
├── references/red-flags.md
├── references/puerta-humana.md
└── references/integracion-sdd.md   ← + nota de mapeo al arnés
```

`assets/plantilla-ddr.md` **no** va acá: va a `docs/design/PLANTILLA-DDR.md`
(§0.2), porque es una plantilla que se copia al proyecto, no material de consulta
del agente.

**La sección `## Precedencia del Craftsman Harness`** va al principio del
SKILL.md, siguiendo el patrón de `ponytail/SKILL.md:26-52`. Siete puntos:

1. Mapeo de vocabulario: `specify`→`spec_partner`, `clarify`→puerta Gherkin,
   `design`→`design_partner`, `plan`/`tasks`→entradas de `feature_list.json`,
   `implement`→`tdd_craftsman`, `review`→`judge`.
2. Carril → puerta: solo `estructural` presenta opciones. El modo `design` puede
   apagar la fase, **nunca** la lente del `judge`.
3. La interfaz congelada **no exime del TDD**. Las Tres Leyes siguen.
4. `arch-review` no existe en este árbol: las decisiones de infraestructura
   escalan al humano.
5. Excepción de seguridad al PASO 3: **no** definir fuera de existencia una falla
   de autorización (`SKILL.md:109` vs `threat-lens`).
6. **No** emitir el bloque YAML `design_gate` (`integracion-sdd.md:63-98`).
7. Normalizar el vocabulario de `Estado` y de carriles (hoy inconsistente entre
   prosa, plantilla y YAML).

### 0.2 Crear `docs/design/`

| Archivo | Qué | Lista de `install.sh` |
|---|---|---|
| `docs/design/PLANTILLA-DDR.md` | La plantilla, desde `assets/plantilla-ddr.md` | `KIT_MACHINERY` — se refresca en `--update` |
| `docs/design/INDEX.md` | Tabla `módulo → DDR → estado`. Nace vacía | `KIT_SEED` — se **preserva** en `--update` |
| `docs/design/DDR-*.md` | Los DDRs reales | **Ninguna** — nunca los toca el instalador |

Que los DDRs no estén en ninguna lista es correcto y deliberado: `install.sh` solo
copia archivos nombrados uno a uno (`install.sh:230-247`), así que lo generado
queda intacto por construcción.

### 0.3 Propagación

- `install.sh:212-224` (`SKILL_FILES`) — **cuatro entradas**, una por archivo:
  `aposd-design/SKILL.md` y los tres `references/`. Si falta una, no se propaga y
  falla en silencio con un `warn`.
- `install.sh:180-188` (`KIT_MACHINERY`) — `docs/design/PLANTILLA-DDR.md`,
  `docs/aposd-integracion.md`, `docs/aposd-plan-implementacion.md`.
- `install.sh:192-196` (`KIT_SEED`) — `docs/design/INDEX.md`.
- `AGENTS.md:55` — añadir `aposd-design` a la celda de skills.
- `AGENTS.md:32-56` — dos filas nuevas: `docs/design/` y `docs/aposd-integracion.md`.

### Repercusiones del Lote 0

| | |
|---|---|
| **Comportamiento** | Ninguno. La skill tiene triggers en su `description`, así que Claude Code **puede** auto-invocarla en una conversación suelta. Eso es deseable y no toca el pipeline |
| **Coste** | Cero en corridas. ~44 KB en el repo |
| **Riesgo** | El único real: olvidar un archivo en `SKILL_FILES` y que las instalaciones remotas queden con la skill a medias |
| **Rollback** | `rm -rf` de los archivos + revertir las 3 listas |

### Verificación

```bash
./init.sh                                   # verde
bash install.sh --update /ruta/a/un/proyecto-de-prueba
ls proyecto-de-prueba/.claude/skills/aposd-design/references/   # 3 archivos
ls proyecto-de-prueba/harness-kit/docs/design/                  # 2 archivos
```

---

## LOTE 1 — La lente de red flags en el `judge`

**Objetivo:** el mayor retorno del plan por el menor cambio. Coste marginal cero
en corridas (es un paso dentro de una que ya ocurre) y ataca el defecto más
frecuente del código generado por LLM.

**Este lote es independiente del Lote 2.** Puedes tenerlo para siempre sin fase de
diseño.

### 1.1 `judge.md` — paso nuevo

El protocolo tiene 9 pasos (`judge.md:16-50`). Insertar **el paso 7** —
inmediatamente después de `threat-lens` (paso 6) y antes de `./init.sh --fast` —
y **renumerar 7→8, 8→9, 9→10**.

Contenido del paso: invocar `aposd-design` en modo review sobre **los archivos que
la feature tocó**, con la tabla de severidad de `red-flags.md:192-198`:

| Severidad | Red flags | Efecto en el veredicto |
|---|---|---|
| **Alta** | Filtración de información (#2), descomposición temporal (#3), código no obvio (#14) | `CHANGES_REQUESTED` |
| **Media** | Módulo somero (#1), sobreexposición (#4), mezcla especial-general (#8), métodos siameses (#9) | Va a `risks`, no bloquea |
| **Baja** | Pasamanos (#5, #6), repetición (#7), comentarios redundantes (#10, #11), nombres vagos (#12) | Observación |

**Empezar solo con severidad ALTA como bloqueante.** Si arrancas bloqueando por
media, el primer sprint es todo `CHANGES_REQUESTED` y la lente se desactiva por
frustración.

### 1.2 `judge.md` — sección del veredicto

Añadir en la plantilla de `progress/judge_<name>.md` (`judge.md:67-95`), entre
`## Seguridad` y `## Checkpoints`:

```markdown
## Diseño (aposd-design)
- Red flags ALTA: BLOQUEANTE <archivo:línea> — <cuál y cómo se corrige>
- Red flags MEDIA/BAJA: <lista corta, o "-">
- Deuda aceptada a conciencia: <con disparador, o "-">
```

### 1.3 `judge.md` — regla dura

En `:111-119`, junto a la de `threat-lens`:

> ❌ Nunca apruebes con un red flag de severidad ALTA abierto y sin justificar.
> Un red flag aceptado a conciencia se escribe con su disparador; uno no dicho es
> una trampa para el que venga después.

### 1.4 `CHECKPOINTS.md` — extender C3

C3 («El código respeta la arquitectura») es el sitio natural. Tres boxes nuevos:

- [ ] Ningún red flag de severidad ALTA sin justificar (`red-flags.md`).
- [ ] Los comentarios dicen lo que el código no puede decir — ninguno parafrasea
      la firma (red flag #10, el más frecuente en código de LLM).
- [ ] Ningún nombre vago: `data`, `info`, `manager`, `helper`, `process`,
      `handle`, `utils` (red flag #12).

### 1.5 `ponytail-review` — deslinde

Añadir una línea en su sección de precedencia (`:19-28`) para que no se pisen:
*ponytail-review busca qué borrar; aposd-design busca si el módulo expone de más o
esconde de menos. Un módulo puede ser mínimo en líneas y pésimo en superficie.*

### Repercusiones del Lote 1

| | |
|---|---|
| **Comportamiento** | El `judge` empieza a rechazar por diseño, no solo por cobertura. **Features que antes pasaban ahora no** |
| **Coste** | Marginal. El `judge` ya es Opus y ya lee el diff. Sube el output, no las corridas |
| **Latencia** | Un poco más de razonamiento en el veredicto. Despreciable frente a la mutación |
| **Riesgo principal** | **Falsos positivos.** "Filtración de información" es un juicio, no un match. Un `judge` sobre-entusiasta puede bloquear por duplicación superficial — que `red-flags.md:50` avisa explícitamente que **no** hay que unificar |
| **Mitigación** | Solo ALTA bloquea; y la lente exige citar `archivo:línea`, así que un hallazgo sin evidencia concreta se descarta |
| **Rollback** | Revertir `judge.md` y `CHECKPOINTS.md` |

### Qué tener en cuenta

- **La renumeración del protocolo es mecánica y se rompe fácil.** El paso 7 nuevo
  desplaza tres pasos y hay referencias cruzadas (`judge.md:46` menciona
  `./init.sh --fast` como paso 7). Revisar el archivo entero, no solo el inserto.
- **El `judge` no tiene `Write`/`Edit`** (`judge.md:4`: `Read, Glob, Grep, Bash`).
  No se le puede pedir que actualice ningún archivo — solo emite el veredicto.
- **Medir antes de seguir al Lote 2.** Tras 3-5 features con la lente puesta:
  ¿cuántos hallazgos ALTA hubo? ¿cuántos eran reales? Si la lente sola ya limpia
  el problema, el Lote 2 tiene menos urgencia de la que parecía.

### Verificación

Correr el `judge` contra una feature ya cerrada que sepas que tiene deuda. Debe
encontrar al menos los red flags baratos (#10 comentarios, #12 nombres). Si
devuelve cero sobre código real, el prompt no está mordiendo.

---

## LOTE 2 — La fase `design_partner` (el lote grande)

**Va entero o no va.** Un DDR que el `tdd_craftsman` ignora es teatro, y una fase
que no se puede apagar es una fase que vas a resentir. Los tres pedazos —fase,
interfaz congelada, modo— son un solo cambio.

### 2.1 `.claude/agents/design_partner.md` (nuevo)

```yaml
---
name: design_partner
description: Decide la estructura antes del TDD. Diagnóstico de complejidad,
  diseñarlo dos veces, y un DDR con la interfaz congelada que el tdd_craftsman
  no puede cambiar. No escribe código ni tests.
tools: Read, Write, Edit, Glob, Grep, Bash
---
```

Protocolo, en el estilo de los otros agentes:

1. Leer `AGENTS.md`, `harness.config.sh`, `docs/architecture.md`,
   `project-spec.md`, el `.feature` **completo, incluidos los tags `@sec`**, y
   `docs/design/INDEX.md`.
2. **Si ya hay un DDR aprobado que cubre el módulo → citarlo y devolver
   `status: done` sin abrir puerta** (`puerta-humana.md:26`). Es el mecanismo
   anti-doble-puerta y el que produce coherencia entre features.
3. Invocar la skill `aposd-design`. PASO 0 (carril) → PASOS 1-8.
4. **Cotizar el costo a 6-12 meses contra las features `pending` de
   `feature_list.json`, por nombre.** No "si escala".
5. Escribir `docs/design/DDR-<id>-<slug>.md` desde
   `docs/design/PLANTILLA-DDR.md`. Estado inicial `propuesto`.
6. Actualizar `docs/design/INDEX.md`.
7. **No** cambiar el `status` de la feature. **No** lanzar al `tdd_craftsman`.

Reglas duras: solo escribe en `docs/design/**`; no escribe código, tests ni
`.feature`; si aparece una decisión de infraestructura (otra base, una cola, otro
servicio) **para y escala al humano** — no la resuelve; **lee 3-5 rutas concretas
de código, no árboles** (D-3) — si necesita barrer, lanza `Explore`.

Contrato de 4 campos:
```
status: done | blocked | partial
artifact: docs/design/DDR-<id>-<slug>.md (carril: <carril>)
risks: <una línea, o "-">
next: <"puerta de diseño" si carril=estructural; "-" si no>
```

### 2.2 Routing de modelo

- `model-map.yaml:48-56` → `design_partner: deep`.
- `model-map.yaml:63-67` → **sin override**. Igual que `spec_partner` y `judge`.
- `craftsman_lead.md:42-44` → añadirlo a la lista de fases que son **siempre**
  `channel=agent`. Y `tools/resolve-model.py` debe devolver `channel: agent` para
  esta fase en **todos** los perfiles.
- `craftsman_lead.md:48-58` → fila nueva en la tabla de invocación:
  `Agent(model="opus")` en las dos columnas.
- `docs/model-fit.md:33-49` → fila en la matriz, con la justificación:
  *composición de juicio, mismo argumento que `spec_partner` y `judge`*.

**Consecuencia que hay que aceptar:** el perfil `opencode_go` pasa de **2 fases
Opus a 3**. Es un encarecimiento real del modo híbrido, no un detalle.

### 2.3 `craftsman_lead.md` — Caso A

Hoy `craftsman_lead.md:168-177` para justo después del `gherkin_author`. Cambia a:

```
2. Lanza gherkin_author → features/<name>.feature (spec_ready)
2bis. Si la fase de diseño está activa (§2.6), lanza design_partner.
      Gatekeeper: verificar que el DDR existe en disco.
3. PARAS. Un solo mensaje con:
   - los escenarios, y
   - la 🚪 PUERTA DE DISEÑO, SOLO si carril == estructural.
   Pedido explícito: "aprobado" (o "aprobado + A").
```

Y en el manejo de la respuesta (tabla de `puerta-humana.md:74-84`):

| Respuesta | Acción del lead |
|---|---|
| "aprobado + A" | Flip del DDR a `aprobado por humano` + rellenar `Interfaz congelada` |
| "aprobado" (sin letra), carril estructural | **No avanzar.** Repreguntar solo la opción |
| Cambia escenarios | El DDR queda inválido: relanzar `gherkin_author` y `design_partner` |
| "hacé lo que te parezca" | Aprobación de la recomendada, estado `aprobado por humano (delegado)` |

**El flip del `Estado` en el DDR lo hace el lead**, no un subagente: es una edición
de docs y es post-decisión-humana. Mismo patrón que el cierre R1
(`craftsman_lead.md:185-190`).

### 2.4 `craftsman_lead.md` — Gatekeeper y diagrama

- `:143-153` → el diagrama del pipeline.
- `:217-250` (Gatekeeper) → qué espera de esta fase. Un `blocked` del
  `design_partner` casi siempre es "esto es una decisión de infraestructura" →
  para y escala, no relanza.
- `:200-206` (escalado de esfuerzo) → fila.

### 2.5 `tdd_craftsman.md` — la interfaz congelada

Sin esto el DDR no hace nada. Insertar tras las pre-condiciones (`:33-37`), con la
plantilla de `integracion-sdd.md:102-129`:

```markdown
## Interfaz congelada (si la feature tiene DDR)

Si `docs/design/DDR-<id>-*.md` existe y su Estado es `aprobado por humano` o
`aplicado por defecto`, su bloque **Interfaz congelada** es un contrato cerrado:

- No cambias la firma. No añades parámetros. No mueves el límite del módulo.
- Preservas los **invariantes** listados. Si alguno es observable, merece su test.
- **Si la interfaz no se puede implementar razonablemente: NO la modifiques.**
  Paras y devuelves `status: partial` con qué parte no cierra y cuál sería el
  mínimo cambio que la haría viable. Es un evento de vuelta a la puerta, no una
  licencia para improvisar.

Antes de cerrar, verifica:
- Comentario de interfaz escrito, sin detalles de implementación.
- Ningún comentario que repita el código.
- Ningún parámetro de configuración sin un caso real que lo justifique.
- Nombres precisos: ningún `data`, `info`, `manager`, `process`, `handle`.
```

Y una regla dura en `:95-105`: *❌ No cambies una interfaz congelada por un DDR
aprobado. Ni siquiera para simplificarla — eso es volver a la puerta.*

### 2.6 El modo apagable

`feature_list.json:4-17`, dentro de `rules`:

```jsonc
"design_default": true,
"design_required_when": "feature has \"design\": true (hereda design_default si falta; ausente = true)"
```

Y campo opcional `"design": true|false` en las entradas.

Precedencia, en `craftsman_lead.md`, una línea:
`feature.design` (si existe) > `rules.design_default` > `true`.
Con la fase encendida, el carril decide la puerta.

**No se toca** `harness.config.sh`, ni `profiles/*.sh`, ni `install.sh --migrate`.

**Por qué el default de lectura tiene que ser `true`:** `feature_list.json` está
en `KIT_SEED` (`install.sh:192-196`), o sea que **se preserva** en `--update`. Las
instalaciones existentes nunca van a recibir la clave. Sin el default de lectura,
quedarían en estado indefinido.

### 2.7 Espejo opencode

`.opencode/agents/tdd_craftsman.md` — añadir el mismo bloque de §2.5, **por path**
(esos agentes no tienen la tool `Skill`).

Y aprovechar para cerrar el drift de C-2: cabecera `covers:`, modo refactor,
pre-condiciones y reglas duras. **No es scope creep**: sin la cabecera `covers:`
el perfil híbrido rompe la mutación y la validación del `judge`, que es un bug
abierto hoy.

Añadir además el **check de divergencia** especificado en D-4: comparar los
encabezados `##` de cada par `.claude/agents/X.md` ↔ `.opencode/agents/X.md` y
avisar de las secciones ausentes en el espejo. Solo estructura, no prosa. Corre en
`init.sh` como *warning*, no como fallo — los dos archivos tienen diferencias
legítimas (frontmatter, la tool `Skill`). Sin este check, el drift vuelve.

### 2.8 El resto de los enganches

| Archivo | Cambio |
|---|---|
| `install.sh:197-200` (`AGENT_FILES`) | `design_partner.md` |
| `docs/workflow.md:10-34` | Diagrama |
| `docs/workflow.md:92-103` | Fila en «quién escribe qué»: DDR ← `design_partner` |
| `AGENTS.md:54` | Fila de agentes |
| `AGENTS.md:76-103` | Pipeline numerado (hoy 9 pasos) |
| `CLAUDE.md:36-47` y el `CLAUDE.md` de la raíz | Lista de subagentes |
| `.claude/skills/progress-log/SKILL.md:33-41` | El DDR es artefacto nuevo — pero vive en `docs/design/`, **no** en `progress/`. Decidirlo explícitamente: el DDR es durable, `progress/` es efímero |
| `CHECKPOINTS.md` | Box en C6: si la feature tiene DDR aprobado, el nombre público y el número de parámetros coinciden con la Interfaz congelada (criterio exacto en D-1) |
| `ponytail/SKILL.md:26-52` | Regla: *ponytail no borra una interfaz congelada por un DDR aprobado* |
| `init.sh` | **Nada.** Ver C-1 y C-3 |

### 2.9 Repercusiones del Lote 2

| | |
|---|---|
| **Comportamiento** | Cambia el pipeline. Es el cambio más grande del arnés desde el modo híbrido |
| **Coste** | +1 corrida Opus por feature con diseño activo. En `opencode_go`, 2→3 fases Opus |
| **Latencia humana** | Sin cambio en el caso común (una parada). En carril estructural la parada exige leer más |
| **Riesgo 1** | **La puerta fusionada desperdicia trabajo si cambias escenarios.** Es la apuesta del diseño. Umbral de revisión: >1 de cada 4 |
| **Riesgo 2** | **El `tdd_craftsman` ignora la interfaz congelada.** Es un prompt, no un compilador. Por eso el `judge` la diffea (C6) — sin ese check el lote es decorativo |
| **Riesgo 3** | **Sobre-clasificación a estructural.** Si todo es estructural, la skill se vuelve un impuesto (`integracion-sdd.md:59`). Señal: dos puertas seguidas en features chicas |
| **Riesgo 4** | El `design_partner` toma decisiones de infraestructura que no le tocan, porque `arch-review` no existe. Mitigación: regla dura de escalar |
| **Rollback** | **El modo apagable ES el kill switch.** `"design_default": false` desactiva la fase sin revertir una línea. El rollback duro (revertir `craftsman_lead.md`) queda de última |

### 2.10 Qué tener en cuenta

- **Los DDRs son por módulo, no por feature.** Si el `design_partner` genera uno
  por feature, perdiste el mecanismo principal contra la amplificación de cambios
  (§5.1 del informe). El paso 2 del protocolo es el que lo evita — **es el paso
  más importante del agente entero.**
- **`docs/design/INDEX.md` es el índice y hay que mantenerlo.** Sin él, el paso 2
  degenera en un glob y el agente termina abriendo puerta por algo ya decidido.
- **Una puerta por vez** (`SKILL.md:190`). Si una feature tiene dos decisiones
  estructurales, se ordenan por dependencia y se presenta la que condiciona.
- **`docs/architecture.md` y los DDRs se van a contradecir**, y la jerarquía ya
  está resuelta en D-2: el marco no se viola, el DDR refina dentro. Escribirla en
  el prompt del `design_partner` **y** en el del `judge`, o cada uno la va a
  interpretar distinto.

### 2.11 Verificación

1. `./init.sh` verde.
2. Una feature de prueba **trivial**: la fase corre, clasifica trivial, escribe un
   DDR de 3 líneas, **no** abre puerta. Es el caso que más va a ocurrir.
3. Una feature **estructural**: la puerta llega en el mismo mensaje que los
   escenarios, con las dos opciones y la recomendación.
4. Con `"design": false`: la fase se salta y el pipeline es idéntico al de hoy.
5. **Prueba negativa:** cambiar a mano una firma para que no coincida con la
   Interfaz congelada. El `judge` tiene que rechazar. Si aprueba, §2.5 no muerde.
6. Perfil `opencode_go`: `resolve-model.py design_partner --field channel` →
   `agent`.

---

## LOTE 3 — Auditoría de complejidad (legacy)

Independiente del Lote 2. Un proyecto con `design_default: false` igual puede
correrla: no es una fase del pipeline, es una invocación de una sola vez.

### 3.1 `docs/complejidad.md` (plantilla, `KIT_MACHINERY`)

Tabla rankeada: hotspot · síntoma · evidencia (`archivo:línea` + nº de co-cambios)
· red flag y severidad · cuál es el próximo cambio que se vuelve caro. Cierra con
la frase de `SKILL.md:82`.

### 3.2 `tools/complexity-scan.sh` (nuevo)

Lo que se puede medir sin herramientas, con `git`:

```bash
# Churn: qué se toca más
git log --format= --name-only -- "$SRC" | sort | uniq -c | sort -rn

# Co-change: qué cambia junto (amplificación de cambios medida)
git log --format="%H" --name-only | awk '...'   # pares por commit, acumulados
```

Salida: TSV con `archivo · commits · co-cambios-top`. **Sin LLM** — es el insumo
barato que después el barrido de lectura interpreta.

- `install.sh` → `KIT_MACHINERY`.
- `.claude/settings.json:30-35` (`permissions.allow`) → `tools/complexity-scan.sh*`.

### 3.3 Procedimiento (en `docs/refactoring.md`)

Sección nueva **antes** de «Divide por seam» (`:34-42`), que hoy asume que ya
sabes cuáles son los seams:

1. `tools/complexity-scan.sh` → churn y co-change.
2. Barrido de lectura: 3-5 `Explore` en paralelo, uno por red flag detectable
   (la tabla de §9 del informe).
3. Rankear por **churn × severidad**. Un red flag alto en un archivo que nadie
   toca hace tres años no es prioridad.
4. `docs/complejidad.md`.
5. **Puerta humana de priorización**: eliges 3 hotspots. El roadmap es información
   que solo tienes tú.
6. Un DDR por hotspot → interfaz objetivo congelada.
7. Traducir a entradas `[REFACTOR]`, una por seam
   (`docs/refactoring.md:92-113` ya tiene la plantilla).

Y **corregir el orden** de `docs/refactoring.md:56`: el DDR va **antes** de la
caracterización, porque es el que dice qué comportamiento pintar. Caracterizar
antes de saber dónde cae el seam produce tests sobre código que va a desaparecer.

### Repercusiones y qué tener en cuenta

| | |
|---|---|
| **Comportamiento** | Ninguno automático. Es un procedimiento que se invoca |
| **Coste** | El scan de git es segundos. El barrido son 3-5 `Explore` en Haiku — barato |
| **Riesgo 1** | **El co-change tiene falsos positivos con commits gigantes.** Un merge que toca 200 archivos los correlaciona a todos. Filtrar commits por encima de N archivos |
| **Riesgo 2** | Repos con historial reescrito o importado de golpe: el churn no dice nada. Detectarlo (¿un commit inicial con el 90% de los archivos?) y avisar en vez de dar números falsos |
| **Riesgo 3** | La auditoría produce una lista larga y desmoralizante. Por eso el paso 5 corta en 3 |
| **Rollback** | Borrar dos archivos y una sección |

**Nota de mutación:** sobre un módulo legacy grande la mutación es brutal en CPU.
`HARNESS_FEAT_SCOPE` y el mapa `covers:` ya existen; acá no son opcionales.

**Sonar, más adelante:** sustituye el paso 2 por medición. El paso 1 (git) y todo
lo demás quedan igual — está diseñado para que Sonar sea evidencia intercambiable,
no dependencia.

---

## LOTE 4 — DDR-000 de esqueleto (opcional)

Solo después de que el Lote 2 tenga rodaje.

En greenfield, si el reparto de módulos no se decide una vez, la feature 1 lo
decide por accidente. Añadir a `harness_bootstrap.md:22-47` un paso: tras
detectar el stack, si el proyecto es nuevo, recomendar un DDR de esqueleto antes
de la primera feature — y que ese DDR sea lo que llene `docs/architecture.md`, que
hoy se completa a ciegas sin haber visto una línea del dominio.

**Riesgo:** diseñar el esqueleto antes de tener una sola feature conversada es
justo el tipo de especulación que APOSD condena (`SKILL.md:260`). Por eso va
**después** del primer `spec_partner`, no en el bootstrap puro. Y por eso es el
último lote: es el más fácil de hacer mal.

---

## Riesgos transversales

### R-1. Dos skills discutiendo en el mismo turno

`ponytail` es always-on por trigger. En una feature estructural, `ponytail` va a
querer borrar la abstracción que `aposd-design` acaba de justificar. El árbitro es
el carril, y tiene que estar escrito en **los dos** SKILL.md, no en uno.

### R-2. Superficie de configuración del arnés

Con esto el kit llega a seis ejes: `active_profile`, `"sdd"`, `"design"`,
`[REFACTOR]`, `--fast`, intensidad de `ponytail`. `"design"` pasa la prueba porque
extiende el eje de `"sdd"` en el mismo objeto — pero es el último que la pasa. El
séptimo va a ser red flag #4 al nivel del arnés.

### R-3. El informe y el plan se van a desactualizar

`docs/aposd-integracion.md` y este archivo describen algo no implementado. En
cuanto el Lote 2 exista, la fuente de verdad pasa a ser `docs/workflow.md` y los
prompts. Marcar ambos como históricos entonces, o quedan dos descripciones del
pipeline en desacuerdo — red flag #2, en la documentación del arnés.

### R-4. Nadie mide si funcionó

El contra-síntoma de éxito es uno y es medible: **la feature N+1 sobre un módulo
con DDR toca menos archivos que las que se hicieron sin él.** Con el mapa
`covers:` eso se cuenta. Si no se registra en `docs/model-fit.md:66-96` durante
las primeras diez features, en tres meses la discusión va a ser de opiniones.

---

## Decisiones cerradas

Las cuatro que quedaban abiertas, resueltas. Van escritas acá porque son las que
el implementador va a necesitar y no se deducen de ningún otro archivo.

### D-1. El `judge` diffea la interfaz congelada: literal en nombre y aridad, interpretado en tipos

**Rechazo mecánico, sin juicio:**

- El **nombre** público no coincide con el del DDR. Un rename es volver a la puerta.
- Cambia el **número de parámetros**. Y esto incluye **añadir uno opcional**:
  un parámetro con default no cambia la aridad para el llamador, pero sí amplía la
  superficie expuesta, que es exactamente lo que el DDR congeló (red flag #4,
  `red-flags.md:66-72`).

**Juicio, pasa si preserva el contrato:**

- Los **tipos**. `list[str]` vs `Sequence[str]`, un alias, un dataclass
  equivalente: son cosméticos y no se rechazan.

**Excepción que vuelve literal a un cambio de tipo:** hacer un parámetro o un
retorno **nullable/opcional** donde el DDR decía que no lo era. Eso no es cosmético
— añade una rama que todos los llamadores tienen que manejar para siempre
(`SKILL.md:109`). Se rechaza.

### D-2. El DDR manda sobre su módulo; `docs/architecture.md` es el marco

Formulación precisa, para que la elección no produzca drift:

- `architecture.md` fija el **marco**: capas, dirección de las dependencias,
  contrato de errores, qué no se hace.
- Un DDR **refina dentro del marco**. Sobre su módulo, gana el DDR.
- Un DDR **no puede violar el marco**. Si necesita hacerlo, eso no es un DDR: es
  un cambio a `architecture.md`, y es una decisión humana aparte.

El `judge` aplica esa jerarquía: contra el marco rechaza siempre; dentro del marco
compara contra el DDR, no contra su gusto.

### D-3. El `design_partner` puede leer código de la app

Necesario para proyectos existentes: sin ver el código no hay diagnóstico de
complejidad, solo adjetivos. Precedente: el `judge` ya tiene `Read` sobre `src/`
sin poder editarlo.

**Con un tope duro de coste** (`integracion-sdd.md:44`): lee **3-5 rutas
concretas**, no árboles. Si no sabe cuáles son, las pide — no barre el repo. Si
necesita un barrido, lanza `Explore`, que corre en Haiku.

### D-4. El drift del espejo opencode se arregla dentro del Lote 2

Ya se toca `.opencode/agents/tdd_craftsman.md` para meter la interfaz congelada, y
el drift es un bug abierto hoy (C-2). Se acepta que infla el lote.

Entregables concretos que esto añade al Lote 2 (§2.7):

1. Portar al espejo: cabecera `covers:`, modo refactor, pre-condiciones y reglas
   duras.
2. Un **check de divergencia**, o el drift vuelve en el próximo cambio. Lo más
   barato que funciona: comparar los encabezados `##` de cada par
   `.claude/agents/X.md` ↔ `.opencode/agents/X.md` y avisar de las secciones que
   faltan en el espejo. No compara prosa — solo estructura, que es donde el drift
   duele. Corre en `init.sh` como *warning*, no como fallo: los dos archivos
   tienen diferencias legítimas (frontmatter, la tool `Skill`).

---

## Resumen del esfuerzo

| Lote | Archivos nuevos | Archivos modificados | Reversible sin dolor |
|---|---|---|---|
| 0 | 5 | 3 | Sí |
| 1 | 0 | 3 | Sí |
| 2 | 1 (+1 si el check de D-4 va aparte) | ~14 | Sí, vía `design_default: false` |
| 3 | 2 | 3 | Sí |
| 4 | 0 | 1 | Sí |

El Lote 2 incluye, por D-4, el arreglo del espejo opencode y su check de
divergencia — trabajo que no es de APOSD pero que hay que hacer igual.

El Lote 2 es el 70% del trabajo y el 100% del riesgo. Los lotes 0, 1 y 3 se pueden
hacer, usar y evaluar sin comprometerse con él.
