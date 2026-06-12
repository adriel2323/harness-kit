---
name: commit-hygiene
description: >
  Disciplina de commits limpios para el Craftsman Harness. Úsala al crear
  cualquier commit, revisar el historial, o limpiar la rama tras completar
  una feature. Activa cuando el trabajo dice "commitea", "haz commit",
  "limpia el historial" o cuando una feature pasó judge + mutación y hay que
  registrarla.
---

# Commit Hygiene

> Transversal al flujo de 5 fases. No cambia el pipeline; gobierna **cómo se
> registra** el trabajo que el pipeline ya validó. Rutas de artefactos
> (`docs/`, `progress/`, `features/`, `feature_list.json`) y comandos
> (`./init.sh`, `tools/...`) se interpretan según la regla de base del
> proyecto (ver `.claude/CLAUDE.md`; en layout consolidado, bajo `harness-kit/`).

## Cuándo se commitea (la puerta)

Una feature `"sdd": true` solo se commitea como entregada cuando está
**`done`**, es decir:

- la suite completa pasa (`./init.sh` en verde / `tools/run-tests.sh`), y
- el `judge` aprobó (`progress/judge_<name>.md`), y
- la mutación supera el umbral de `docs/mutation-testing.md`
  (`progress/mutation_<name>.md`, vía `tools/run-mutation.sh`).

Commits intermedios del ciclo TDD (rojo→verde→refactor) son válidos como
checkpoints, pero **no mezcles dos features en un mismo commit ni en una
misma sesión** (regla "una feature a la vez", ver `AGENTS.md` §3).

## Formato (Conventional Commits)

```
<tipo>(<scope opcional>): <asunto en imperativo, ≤72 chars, sin punto final>

<cuerpo: el porqué, no el qué; referencia el contrato>

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

Tipos: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`. El scope suele ser
el módulo o la feature (`feat(<feature>): ...`).

## El cuerpo referencia el contrato (anti-teléfono)

El commit es trazable al contrato ejecutable, no a una descripción suelta:

- Cita los escenarios cubiertos: `features/<name>.feature` (`@s1..@sn`).
- Apunta a las bitácoras: `progress/tdd_<name>.md`, `progress/judge_<name>.md`,
  `progress/mutation_<name>.md`.
- Incluye el score de mutación si la feature cerró (`X% ≥ umbral`).

## Checklist antes de commitear

- [ ] Suite completa en verde.
- [ ] Un solo cambio lógico; nada de features mezcladas.
- [ ] `progress/current.md` actualizado con el estado real.
- [ ] Sin artefactos generados (build, caches) — deben estar en `.gitignore`.
- [ ] Asunto imperativo y conciso; cuerpo explica el porqué.
- [ ] Trailer `Co-Authored-By` presente.

## Qué NO hacer

- ❌ Commitear con la suite roja o sin pasar el umbral de mutación.
- ❌ Marcar una feature `done` en `feature_list.json` desde aquí: eso lo hace
  el `tdd_craftsman` solo tras judge + mutación (ver `CLAUDE.md`).
- ❌ Hacer `push` sin que el humano lo pida explícitamente.
- ❌ Commits "varios arreglos": un commit, un cambio.
