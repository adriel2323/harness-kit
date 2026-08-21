# El flujo Uncle Bob (Harness Engineering, edición artesano)

> Este arnés organiza el trabajo alrededor del proceso que Robert C. Martin
> describe en su hilo: **conversar la spec, destilarla en escenarios Gherkin,
> tallar el código con TDD estricto, podar con juicio y validar con prueba de
> mutación**. El arnés es agnóstico al lenguaje; lo que enseña es el *proceso*.

## El pipeline de un vistazo

```
(una vez por proyecto)
  harness_bootstrap — DETECCIÓN ────────────────►  harness.config.sh + docs personalizados

pending
  │  spec_partner — CONVERSACIÓN  ───────────────►  project-spec.md
  │      "We debate various topics and decisions."
  │
  │  gherkin_author — DESTILACIÓN ───────────────►  features/<name>.feature
  │      ".feature files from the project-spec.md"
  │
  │  design_partner — DISEÑO ────────────────────►  docs/design/DDR-<id>-<slug>.md
  │      dónde vive el código y qué firma tiene, antes de que exista
  │      (fase apagable; el carril decide si abre puerta)
  │
  ▼  ⏸  PUERTA HUMANA: el humano aprueba los escenarios (el contrato)
  │      + elige la opción de diseño, si el carril es estructural
  │
in_progress
  │  tdd_craftsman — ROJO → VERDE → REFACTOR ────►  código + tests
  │      un test a la vez; las Tres Leyes del TDD
  │
  │      dentro de la interfaz congelada del DDR, si lo hay
  │
  │  judge — REVIEW ─────────────────────────────►  progress/judge_<name>.md
  │      "The review step is the whole game. Agents draft, judgment prunes."
  │
  │  mutation_tester — MUTACIÓN ─────────────────►  progress/mutation_<name>.md
  │      "Mutation testing is resource-heavy, but the ROI is worth every cycle."
  ▼
done
```

Una sola feature a la vez. Una sola puerta de aprobación humana: sobre los
escenarios Gherkin —y, si el carril de diseño es `estructural`, sobre la opción
de diseño— **antes** de escribir producción.

## Fase 0 — Bootstrap (una vez por proyecto)

Antes del flujo, el `harness_bootstrap` detecta/confirma el lenguaje, rellena
`harness.config.sh` (comandos de test, mutación, build) y personaliza
`docs/architecture.md` y `docs/conventions.md` con las reglas reales del
stack. Sin esto, el resto del arnés no sabe cómo correr nada. Para un proyecto
existente, no toca el código: solo describe sus reglas y siembra
`feature_list.json`.

## Por qué este orden (los insights del hilo)

### 1. La spec nace de una conversación, no de un dictado
El humano no entrega un documento cerrado. Debate con el `spec_partner`:
casos límite, contratos de salida, alternativas descartadas. El resultado,
`project-spec.md`, es el acuerdo razonado — incluidas las **decisiones** y
su porqué. Una spec sin debate esconde los huecos; el debate los saca.

### 2. Gherkin convierte la prosa en un contrato ejecutable
> "Once the project-spec.md is done, I have it create a set of .feature
> files."

Cada comportamiento se vuelve un `Scenario` con `Given/When/Then`
verificable. Esto es lo que el humano firma. A partir de aquí, la
ambigüedad es un bug del contrato, no del código. Ver `docs/gherkin.md`.

### 3. La puerta humana va sobre el contrato, no sobre el código
Aprobar tarde (cuando ya hay código) es caro. Aprobar el `.feature` es
barato y es el punto de máximo apalancamiento: un escenario mal definido
arrastra todo el TDD. El `craftsman_lead` **para** aquí y espera.

### 3bis. El diseño va después del Gherkin y antes del TDD

Tres razones que apuntan al mismo lado:

1. La fase de diseño es **la única del ciclo donde cambiar de idea es gratis**.
   Todo lo que se decide después cuesta código escrito.
2. Los escenarios son el insumo que hace **evaluable** el "diseñarlo dos veces":
   la opción A y la B se comparan por el costo de un requerimiento futuro
   **concreto** — las features `pending` de `feature_list.json`, por nombre. Sin
   escenarios no hay con qué cotizar.
3. Primero el QUÉ, después el CÓMO. Mezclarlos hace que la discusión de diseño
   contamine el contrato de comportamiento.

Sin esta fase, el `tdd_craftsman` **inventa la estructura feature por feature**.
Sobre N features eso produce N módulos localmente óptimos y globalmente
incoherentes. El `judge` puede olerlo, pero solo cuando el código ya existe y
cambiar de idea cuesta.

**Es una fase, no una segunda puerta.** El diseño viaja en la misma parada que
los escenarios. Y solo el carril `estructural` presenta opciones para elegir:
en `trivial` y `estandar` el DDR se registra como `aplicado por defecto` y la
parada muestra solo los escenarios, como siempre.

**El DDR es por módulo, no por feature.** Antes de diseñar nada, el
`design_partner` busca en `docs/design/INDEX.md` si el módulo ya tiene decisión
tomada: si la tiene, la cita y sigue. Así la feature #7 **hereda** la interfaz
en vez de inventar la séptima abstracción del mismo concepto.

**Se puede apagar** (`rules.design_default` o `"design": false` por feature).
Lo que se apaga es **la fase**, nunca **la lente**: el `judge` sigue aplicando
el catálogo de red flags siempre, porque cuesta cero corridas extra.

### 4. TDD estricto: un test a la vez
> "single test followed by code (TDD)"

No se escriben todos los tests por adelantado. Se vive el ciclo pequeño:
un test rojo → el mínimo verde → refactor en verde. Las Tres Leyes en
`docs/tdd.md`. El código que ningún test pidió no existe.

### 5. El review es el juego entero
> "Agents draft, judgment prunes."

Generar borradores es barato (el modelo teclea infinito). El valor escaso
es el **juicio** que decide qué sobrevive. El `judge` no edita: poda. Si un
escenario no tiene test, o hay código que nadie pidió, rechaza.

### 6. La validación es el nuevo cuello de botella, y es compute-bound
> "Raw computer power is the limiting factor." / "Mutation testing is
> resource-heavy, but the ROI on code correctness is worth every cycle."

Una suite verde solo dice que el código no explota, no que los tests
sirvan. La prueba de mutación introduce defectos y exige que algún test
falle. Es cara en CPU —reejecuta la suite por cada mutante— pero es la
medida real de si la red atrapa peces. Ver `docs/mutation-testing.md`.

## Mapa de artefactos (quién escribe qué)

| Archivo                          | Lo escribe        | Contiene                                            |
|----------------------------------|-------------------|-----------------------------------------------------|
| `harness.config.sh`              | harness_bootstrap | Comandos por lenguaje (test, mutación, build)       |
| `project-spec.md`                | spec_partner      | Spec conversada: propósito, contrato, decisiones    |
| `features/<name>.feature`        | gherkin_author    | Escenarios Gherkin `@s1..@sn` (el contrato firmado) |
| `docs/design/DDR-<id>-<slug>.md` | design_partner    | Decisión de diseño **por módulo**: opciones, descartadas y **interfaz congelada** |
| `docs/design/INDEX.md`           | design_partner (fila) + craftsman_lead (estado) | Índice `módulo → DDR → estado`: lo que evita abrir puerta dos veces |
| código + tests                   | tdd_craftsman     | Producción y tests, tallados por TDD                |
| `progress/tdd_<name>.md`         | tdd_craftsman     | Bitácora de ciclos + mapa `@s → test`               |
| `progress/judge_<name>.md`       | judge             | Veredicto de review + checkpoints                   |
| `progress/mutation_<name>.md`    | mutation_tester   | Score de mutación + mutantes sobrevivientes         |
| `feature_list.json`              | craftsman_lead (estados intermedios y cierre `done` via R1) | `pending → spec_ready → in_progress → done` |

Regla anti-teléfono-descompuesto: los subagentes escriben en disco y
devuelven un **contrato de 4 líneas** (`status` / `artifact` / `risks` /
`next`) que el `craftsman_lead` valida como gatekeeper. El contenido no circula
por chat.
