# Plan de mejoras — preparación de specs/requerimientos

> Origen: análisis comparativo entre el workflow SDD de **gentle-ai**
> (`explore → propose → spec → design → tasks → apply → verify → archive`,
> con OpenSpec interno) y el flujo **Uncle Bob** de este repo
> (`project-spec → Gherkin → puerta humana → TDD → judge → mutación`).
> Fecha del análisis: 2026-06-24.

## Objetivo

Subir la calidad de la **fase de preparación de spec** (conversación,
requerimientos, contrato) sin inflar el flujo minimalista ni romper sus
ventajas. Todas las mejoras son *para escalar a proyectos reales*, no para
complicar el ejemplo didáctico `notes-cli`.

## Lo que NO se toca (fortalezas a preservar)

- Spec conversada/debatida (`spec_partner`).
- Gherkin como contrato firmado en la puerta humana (máximo apalancamiento).
- Puerta de aprobación humana única, antes de producción.
- TDD estricto (un test a la vez) + **prueba de mutación** (gentle-ai no la tiene).
- Estado en disco, hand-off de una línea (anti-teléfono-descompuesto).

## Decisión pendiente

- [ ] ¿Sobre qué base se aplica? Opciones: **repo de ejemplo**,
      **`craftsman-harness-kit`** (lo que se distribuye), o **ambos**.
      Recomendado: aplicar al kit y reflejar en el ejemplo.

---

## P1 — Alto impacto, bajo riesgo (empezar por aquí)

### 1. Taxonomía de preguntas en `spec_partner`
- **Qué**: reemplazar los ~4 prompts de ejemplo por una taxonomía de 10 ejes
  + protocolo de ronda.
- **Ejes**: problema de negocio · usuarios/situación · reglas de negocio ·
  resultado esperado · gap actual · implicaciones/impacto · casos límite ·
  gaps de decisión · límites de alcance/no-goals · riesgo/tradeoff.
- **Protocolo**: 3–5 preguntas concretas por ronda; al responder, resumir
  supuestos resultantes y ofrecer una segunda ronda o correcciones.
- **Archivos**: `.claude/agents/spec_partner.md` (y versión del kit).
- **Referencia**: fase `sdd-propose` de gentle-ai.

### 2. "Fuera de alcance / No-goals" explícito
- **Qué**: añadir sección **Fuera de alcance** a cada feature en
  `project-spec.md` y un campo equivalente en `feature_list.json`.
- **Por qué**: refuerza el valor declarado "el alcance no se infla".
- **Archivos**: plantilla de `project-spec.md`, esquema de `feature_list.json`,
  protocolo de `spec_partner.md`.

### 3. Result Contract estructurado en el hand-off de agentes
- **Qué**: ampliar la salida de una línea a un contrato con
  `status (done|blocked|partial)` + `risks` + `next_recommended` (además de la
  referencia al artefacto).
- **Por qué**: el `craftsman_lead` podría reaccionar a `blocked`/`partial`.
  El estado `blocked` ya existe en `feature_list.json` pero ningún agente lo emite.
- **Archivos**: todos los `.claude/agents/*.md` (sección "Comunicación") +
  `craftsman_lead.md` (cómo interpretar el contrato).

---

## P2 — Valor en proyectos no triviales

### 4. Paso de exploración previo al debate
- **Qué**: leer código existente + comparar enfoques con tabla pros/cons/esfuerzo
  antes de conversar la spec. Plegarlo en el protocolo de `spec_partner` o como
  paso/agente ligero (`explorer`).
- **Por qué**: en un repo real el `spec_partner` debate en el vacío sin esto.
  Innecesario en `notes-cli`.
- **Referencia**: fase `sdd-explore` de gentle-ai.

### 5. Nota de diseño opcional, gateada por complejidad
- **Qué**: para cambios con decisiones de arquitectura, una `design`-note
  (decisiones + **alternativas rechazadas** + tabla de archivos a tocar).
  Solo cuando aplica; el flujo spec→TDD sigue por defecto.
- **Por qué**: hoy esas decisiones quedan dispersas en el spec.
- **Referencia**: fase `sdd-design` de gentle-ai.

### 6. Reglas por fase en formato máquina
- **Qué**: subir a `harness.config.sh` (o un `config.yaml` análogo) las reglas
  por fase que hoy viven en prosa repartida entre `AGENTS.md` / `CLAUDE.md` / `docs/`.
- **Por qué**: una sola fuente de verdad; el kit ya tiene umbral de mutación y
  comandos de test ahí.
- **Referencia**: `openspec/config.yaml` de gentle-ai.

---

## P3 — Refinamiento

### 7. Matriz de trazabilidad consolidada
- **Qué**: artefacto único `acceptance → @s → test → mutante`.
- **Estado actual**: las piezas existen sueltas (`@s→test` en `tdd_*.md`,
  cobertura en el judge, mutación aparte).

### 8. Anti-drift del contrato
- **Qué**: chequear que `acceptance[]` (feature_list), `project-spec.md` y el
  `.feature` no se contradigan (hoy el contrato se reescribe en 3 sitios).

---

## Orden sugerido de ejecución

1. P1.1 + P1.2 + P1.3 (ediciones contenidas a agentes y plantillas).
2. P2.6 (centralizar reglas) antes que P2.4/P2.5 para tener dónde declararlas.
3. P2.4, luego P2.5.
4. P3.7, P3.8.
