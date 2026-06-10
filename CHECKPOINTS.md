# CHECKPOINTS — Evaluación del estado final

> En sistemas multi-agente no se evalúa el camino, se evalúa el destino.
> Estos son los checkpoints objetivos que un juez (humano o IA) puede usar
> para decidir si el proyecto está sano. Son **agnósticos al lenguaje**:
> donde se mencionan comandos, se refieren a los de `harness.config.sh`.

## C1 — El arnés está completo

- [ ] `harness.config.sh` existe y `HARNESS_LANGUAGE` no vale `TODO`.
- [ ] Existen los archivos base: `AGENTS.md`, `init.sh`, `feature_list.json`,
      `progress/current.md`.
- [ ] Existen los 3 docs de calidad: `docs/architecture.md`,
      `docs/conventions.md`, `docs/verification.md`, y están **personalizados**
      al stack (no quedan marcadores de plantilla).
- [ ] `./init.sh` termina con exit code 0.

## C2 — El estado es coherente

- [ ] Como mucho una feature en `in_progress` en `feature_list.json`.
- [ ] Toda feature `done` tiene tests asociados que pasan.
- [ ] `progress/current.md` está vacío o describe la sesión activa
      (no contiene basura de sesiones anteriores).

## C3 — El código respeta la arquitectura

- [ ] El código solo contiene los módulos/capas previstos en
      `docs/architecture.md`.
- [ ] No hay dependencias externas no justificadas (las que haya están
      documentadas como decisión en `feature_list.json` o `project-spec.md`).
- [ ] No hay prints/logs de debug sueltos, ni TODOs sin contexto.

## C4 — La verificación es real

- [ ] Hay al menos un test por módulo/unidad del código.
- [ ] Los tests usan recursos reales aislados (directorios temporales, fakes
      acotados) en vez de mockear el sistema cuando un recurso real es viable.
- [ ] `HARNESS_TEST_CMD` muestra > 0 tests y todos verdes.

## C5 — La sesión se cerró bien

- [ ] No hay archivos sin trackear sospechosos (temporales, cachés fuera del
      `.gitignore`).
- [ ] `progress/history.md` tiene una entrada por la última sesión.
- [ ] La última feature trabajada está reflejada en su estado correcto.

## C6 — Contrato Gherkin (BDD)

- [ ] Toda feature con `"sdd": true` en estado `spec_ready`, `in_progress`
      o `done` tiene su `features/<name>.feature` y una sección en
      `project-spec.md`.
- [ ] El `.feature` usa Gherkin con escenarios tagueados `@s1`, `@s2`, …
      y cada `Then` afirma algo medible (ver `docs/gherkin.md`).
- [ ] Cada escenario `@s` está cubierto por al menos un test concreto
      (mapa `@s → test` en `progress/tdd_<name>.md`).
- [ ] No hay código de producción que ningún test rojo haya pedido
      (disciplina TDD, ver `docs/tdd.md`).

## C7 — Prueba de mutación

- [ ] La feature `done` superó la prueba de mutación
      (`HARNESS_MUTATION_CMD` sobre los archivos tocados) con la puntuación
      por encima del umbral de `docs/mutation-testing.md`
      (`HARNESS_MUTATION_THRESHOLD`).
- [ ] Cualquier mutante sobreviviente queda documentado en
      `progress/mutation_<name>.md` (matado con un test nuevo, o
      justificado como equivalente).

---

**Cómo usar este archivo:** el agente `judge` (`.claude/agents/judge.md`)
recorre C1-C6 y el `mutation_tester` valida C7. Se rechaza el cierre de
sesión si quedan boxes vacíos.
