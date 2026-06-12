---
name: branch-pr
description: >
  Flujo de rama y Pull Request por feature en el Craftsman Harness. Úsala al
  crear una rama de trabajo o al abrir/preparar un PR de una feature
  completada. Activa cuando el trabajo dice "abre un PR", "crea la rama",
  "prepara para review" o cuando una feature llegó a `done` y hay que
  integrarla.
---

# Branch & PR

> Transversal al flujo de 5 fases. Una rama por feature, un PR por feature:
> espeja la regla "una feature a la vez". Rutas de artefactos y comandos se
> interpretan según la regla de base del proyecto (ver `.claude/CLAUDE.md`).

## Rama

- Una rama por feature, nombrada por su id en `feature_list.json`:
  `feature/<name>` (p. ej. `feature/cli_count`).
- Parte de la rama de integración/base del proyecto (la que el repo use como
  tronco), no de una feature anterior. Si dudas, pregunta al humano.
- No acumules varias features en una rama. Si la sesión cambió de feature,
  cambia de rama.

## La puerta de PR

Un PR se abre **solo** cuando la feature está `done`:

- suite completa en verde (`./init.sh` / `tools/run-tests.sh`), y
- `judge` aprobó (`progress/judge_<name>.md`), y
- mutación sobre umbral (`progress/mutation_<name>.md`).

No abras un PR de trabajo a medias. Si es WIP y el humano lo pide, márcalo
explícitamente como borrador.

## El cuerpo del PR enlaza el contrato (anti-teléfono)

El revisor no debería tener que adivinar nada: el PR apunta a los artefactos
en disco, no narra el contenido.

- **Contrato firmado:** `features/<name>.feature` y los escenarios `@s1..@sn`.
- **Spec y decisiones:** la sección relevante de `project-spec.md`.
- **Evidencia de validación:**
  - `progress/judge_<name>.md` (veredicto del review).
  - `progress/mutation_<name>.md` (score + mutantes sobrevivientes).
  - Resultado de la suite (verde).
- Trailer al final del cuerpo:
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

## Merge gate

Mergeable solo cuando:

- checks en verde,
- **todos** los escenarios del `.feature` están mapeados a un test
  (`progress/tdd_<name>.md`),
- el `judge` no dejó código que ningún escenario pidió,
- mutación ≥ umbral de `docs/mutation-testing.md`.

Si algo falta, se piden cambios con ítems accionables; no se mergea "casi".

## Qué NO hacer

- ❌ `push` o abrir PR sin que el humano lo pida explícitamente.
- ❌ PR que mezcla dos features.
- ❌ PR sin enlace al `.feature` ni a las bitácoras de `progress/`.
- ❌ Mergear con escenarios sin test o mutación bajo umbral.
