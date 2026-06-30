# AGENTS.md — Mapa de navegación para agentes de IA

> Punto de entrada para cualquier agente que trabaje en este repositorio.
> NO es una biblia de reglas: es un **mapa**. Lee solo lo que necesites
> cuando lo necesites (divulgación progresiva).
>
> **Flujo estilo Robert C. Martin** — conversación → Gherkin → TDD → review →
> mutación. Agnóstico al lenguaje: los comandos viven en `harness.config.sh`.
> Ver `docs/workflow.md`.

---

## 1. Antes de empezar (obligatorio)

1. Lee `harness.config.sh`. Si `HARNESS_LANGUAGE` vale `TODO`, falta el
   **bootstrap**: corre `harness_bootstrap` (o rellena la config a mano)
   antes de tocar nada.
2. Ejecuta `./init.sh` y verifica que termina sin errores. Si falla, **para**
   y resuelve el entorno antes de tocar código.
3. Lee `progress/current.md` para entender en qué estado quedó la última sesión.
4. Lee `feature_list.json`. Toda feature nueva (`"sdd": true`) recorre el
   pipeline de cinco fases — ver `docs/workflow.md` y §4.
5. Lee `docs/workflow.md` antes de coordinar nada.
6. Lee `model-map.yaml` **una sola vez** y cachea la resolución `fase → modelo`
   antes de lanzar cualquier subagente. Según `active_profile`:
   - `anthropic`: `spec`/`judge`=opus, `gherkin`/`tdd`=sonnet, resto=haiku
   - `opencode_go`: `spec`/`judge`=Claude Opus (Agent); `gherkin`→GLM-5.2,
     `tdd`→DeepSeek V4 Pro, `mutation`/`bootstrap`→DeepSeek V4 Flash (opencode).

## 2. Mapa del repositorio

| Archivo / carpeta            | Qué contiene                                                                | Cuándo leerlo |
|------------------------------|-----------------------------------------------------------------------------|---------------|
| `harness.config.sh`          | Comandos por lenguaje (test, mutación, build, lint, runtime)                | Siempre, al empezar |
| `feature_list.json`          | Lista de tareas con estado (`pending` / `spec_ready` / `in_progress` / `done` / `blocked`) | Siempre, al empezar |
| `progress/current.md`        | Estado de la sesión actual                                                  | Siempre, al empezar |
| `progress/history.md`        | Bitácora append-only de sesiones anteriores                                 | Si necesitas contexto histórico |
| `project-spec.md`            | Spec conversada: propósito, contrato y decisiones por feature               | Antes de destilar Gherkin o implementar |
| `features/<name>.feature`    | Escenarios Gherkin (el contrato ejecutable que el humano aprueba)           | Antes de empezar el ciclo TDD |
| `docs/workflow.md`           | El pipeline completo y los insights de cada fase                            | Antes de coordinar |
| `docs/tdd.md`                | Las Tres Leyes del TDD; el ciclo Rojo-Verde-Refactor                        | Antes de escribir código |
| `docs/gherkin.md`            | Cómo escribir `.feature`; de Gherkin a test                                 | Antes de redactar/leer escenarios |
| `docs/mutation-testing.md`   | Por qué y cómo; umbral; tabla de herramientas por lenguaje                  | Antes de validar la suite |
| `docs/refactoring.md`        | Cómo llevar un refactor/SOLID/desacople por el flujo (caracterización)      | Antes de tocar una feature `[REFACTOR]` |
| `docs/architecture.md`       | Qué significa "hacer un buen trabajo" en este proyecto                      | Antes de implementar |
| `docs/conventions.md`        | Reglas de estilo, nombres, estructura                                       | Antes de escribir código |
| `docs/verification.md`       | Cómo verificar que tu trabajo funciona                                      | Antes de declarar `done` |
| `CHECKPOINTS.md`             | Criterios objetivos de "estado final correcto"                              | Para auto-evaluarte |
| `tools/mutate.py`            | Mutador sin dependencias (Python; fallback genérico)                        | Fase de mutación |
| `tools/run-tests.sh`         | Wrapper agnóstico: corre la suite (`--one <file>` para un solo test)         | Para verificar |
| `tools/test-affected.sh`     | Hook PostToolUse: corre solo el test del archivo editado (loop rápido)       | Automático tras Edit/Write |
| `tools/run-mutation.sh`      | Wrapper: corre la mutación desde la raíz del proyecto, con el entorno cargado | Fase de mutación |
| `.opencode/agents/`         | Subagentes opencode Go (`gherkin_author`, `tdd_craftsman`, `mutation_tester`) — para el perfil híbrido | Si `active_profile` == `opencode_go` |
| `.claude/agents/`            | `harness_bootstrap`, `craftsman_lead`, `spec_partner`, `gherkin_author`, `tdd_craftsman`, `judge`, `mutation_tester` | Si orquestas trabajo |
| `.claude/skills/`            | `commit-hygiene` (commits limpios), `branch-pr` (rama y PR), `progress-log` (bitácoras y anti-teléfono) | Al commitear, PR o registrar progreso |
| `model-map.yaml`             | Fuente de verdad `fase → tier → modelo` (perfiles anthropic y opencode_go); se lee 1× al arrancar | Antes de lanzar subagentes |

> Las rutas del código y los tests no están hardcodeadas: las define
> `HARNESS_SRC_DIR` y `HARNESS_TESTS_DIR` en `harness.config.sh`.

## 3. Reglas duras (no negociables)

- **Una sola feature a la vez.** No mezcles cambios de varias tareas en la misma sesión.
- **No declares una tarea `done` sin pruebas verdes Y umbral de mutación
  superado.** Ejecuta `./init.sh` y la prueba de mutación.
- **No saltes la conversación de spec ni la destilación Gherkin.** Toda
  feature con `"sdd": true` pasa por `spec_partner` y `gherkin_author`.
- **No saltes la puerta de aprobación humana** sobre los `.feature`. El
  `craftsman_lead` detiene el flujo en `spec_ready` y espera.
- **TDD estricto: un test a la vez.** Nada de producción sin un test rojo
  que la pida (`docs/tdd.md`).
- **Documenta lo que haces** en `progress/current.md` mientras trabajas.
- **Deja el repositorio limpio** antes de cerrar la sesión (ver §5).
- **Si no sabes algo, busca en `docs/`** antes de inventarlo.

## 4. Flujo de trabajo (pipeline)

```
(bootstrap una vez: harness_bootstrap → harness.config.sh + docs personalizados)

pending
  → [spec_partner]   conversación → project-spec.md
  → [gherkin_author] project-spec.md → features/<name>.feature   (status: spec_ready)
  → ⏸ HUMANO APRUEBA los escenarios
  → in_progress
  → [tdd_craftsman]  Rojo → Verde → Refactor (un test a la vez)
  → [judge]          review (el juego entero)
  → [mutation_tester] mata mutantes; valida que los tests muerden
  → done
```

1. El `craftsman_lead` detecta la primera feature `pending` con `"sdd": true`.
2. Lanza `spec_partner` (conversa y debate) → `project-spec.md`.
3. Lanza `gherkin_author` → `features/<name>.feature`, status `spec_ready`.
4. **Pausa.** El humano lee los escenarios y aprueba (o pide cambios).
5. Aprobado → status `in_progress` y lanza `tdd_craftsman`.
6. El `tdd_craftsman` recorre cada escenario `@s` con ciclos Rojo-Verde-Refactor.
7. El `judge` revisa cobertura, disciplina TDD y calidad; aprueba o rechaza.
8. El `mutation_tester` corre la mutación; exige el umbral.
9. Si todo pasa, el **`craftsman_lead`** verifica de disco `judge=done` y
   `mutation_tester=done`, hace el flip a `status: done` en `feature_list.json`
   y mueve el resumen a `progress/history.md` (R1 — el cierre es suyo, no del
   `tdd_craftsman`).

## 5. Cierre de sesión (lifecycle)

Antes de terminar:

1. Ejecuta `./init.sh` — todo verde.
2. Corre la prueba de mutación sobre lo tocado — supera el umbral.
3. Si la tarea está acabada: marca `status: "done"` en `feature_list.json`.
4. Mueve el resumen de `progress/current.md` al final de `progress/history.md`.
5. Vacía `progress/current.md` dejando solo la plantilla.
6. No dejes archivos temporales, ni prints de debug, ni TODOs sin contexto.

## 6. Si te bloqueas

- Relee la sección relevante de `docs/`.
- Si la herramienta no hace lo que esperas, **no inventes un workaround**:
  documenta el bloqueo en `progress/current.md` y para la sesión.
