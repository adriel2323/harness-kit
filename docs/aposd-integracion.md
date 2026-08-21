# Incorporar APOSD (Ousterhout) al Craftsman Harness

> **Estado: histórico.** Implementado (lotes 0-3, 2026-08-10). Este documento
> conserva **el razonamiento**: por qué la fase existe, qué arbitraje se hizo
> entre Ousterhout y Uncle Bob, y —lo más útil— **qué puede y qué no puede
> verificar el arnés** (§6). Para saber **cómo funciona hoy** el pipeline, la
> fuente de verdad es `docs/workflow.md` y los prompts de `.claude/agents/`,
> no este archivo: donde discrepen, manda el prompt.
>
> Diferencias conocidas con lo implementado: **no** se añadió el estado
> `design_ready` del §3 (la fase se verifica por existencia del DDR en disco);
> el §11 es el mapa de enganches original, ejecutado con las correcciones de
> `docs/aposd-plan-implementacion.md`.
>
> Skill analizada: `utils/aposd-design/` — 5 archivos, 814 líneas, 100% markdown.
> Referencia: *A Philosophy of Software Design*, John Ousterhout.

## El problema que resuelve

Hoy el arnés no tiene fase de diseño. `docs/workflow.md:10-34` va de la puerta
humana sobre el Gherkin directo al TDD. El `tdd_craftsman` recibe un `.feature`
aprobado e **inventa la estructura** feature por feature.

Sobre N features eso produce N módulos localmente óptimos y globalmente
incoherentes: la *classitis* que Ousterhout describe. El `judge` puede olerlo —
`judge.md:36-38` marca "5+ módulos en la cabecera `covers:`" como smell de módulo
dios — pero solo cuando el código ya existe y cambiar de idea cuesta.

La fase de diseño es la única del ciclo donde cambiar de idea es gratis. Todo lo
que se decide después cuesta código escrito.

---

## 1. Diagnóstico de encaje

### Lo que la skill aporta y el arnés no tiene

El `judge` ya tiene lente de artesano, pero **a nivel función**: funciones cortas,
nombres reveladores, sin duplicación, sin números mágicos (`judge.md:27-38`). No
tiene ninguna lente **a nivel módulo**: ¿la interfaz es profunda? ¿filtra
información? ¿la descomposición sigue el orden de ejecución en vez del reparto de
conocimiento?

Son preguntas distintas, y la segunda familia es la que decide si la feature N+1
sale barata. Una función de tres líneas impecable dentro de un módulo somero no
salva a nadie.

### Lo que no encaja tal cual

| Problema | Dónde | Resolución |
|---|---|---|
| Vocabulario spec-kit (`specify → clarify → plan → tasks`) | `SKILL.md:39-45`, `integracion-sdd.md:10` | Sección de precedencia que mapea a las fases del arnés |
| Referencia colgante a la skill `arch-review` | `SKILL.md:14`, `integracion-sdd.md:133-146` | No existe en este árbol. Las decisiones de infraestructura escalan al humano |
| Vocabulario inconsistente: `estándar` vs `estandar`; los conjuntos de `Estado` no coinciden entre prosa, plantilla y YAML | `SKILL.md:224`, `plantilla-ddr.md:13`, `integracion-sdd.md:70-72` | Normalizar al adaptar |
| Ejemplos anclados a otro dominio (padrón, turnos) | varios | Cosmético, no bloquea |

### Recomendación: no emitir el bloque YAML `design_gate`

`integracion-sdd.md:63-98` define un bloque YAML legible por máquina, pero la
propia skill lo condiciona: *"Emitilo **solo si** el orquestador lo consume. Si
nadie lo parsea, es complejidad autoinfligida"* (`SKILL.md:238`).

El `craftsman_lead` no necesita YAML. La plantilla DDR ya tiene una tabla de
metadata con una fila `| Estado |` (`plantilla-ddr.md:9-15`); un `grep` sobre esa
fila alcanza para el gate. Añadir un parser sería aplicarle a la skill exactamente
lo que la skill combate.

---

## 2. El arbitraje Ousterhout ↔ Uncle Bob

El conflicto es real y está documentado: Ousterhout considera al TDD programación
táctica —enfocada en hacer funcionar features, no en encontrar el mejor diseño—;
Martin sostiene que el paso Refactor *es* el diseño. Este arnés lleva el nombre de
Uncle Bob en el flujo, así que hay que resolverlo explícitamente y no dejarlo
implícito.

**Se toma partido por APOSD en lo estructural.** Tabla de jurisdicción:

| Decisión | Quién manda | Cuándo |
|---|---|---|
| Límites de módulo, qué esconde cada uno | APOSD (DDR) | Antes del TDD, congelado |
| Interfaz pública / firmas | APOSD (DDR) | Antes del TDD, congelado |
| Qué es error y qué se define fuera de existencia | APOSD (PASO 3) | Antes, congelado |
| Estructura interna de la implementación | TDD | Dentro del ciclo |
| Qué test escribir y en qué orden | TDD | Ciclo |
| Refactor intra-módulo | TDD (paso Refactor), guiado por red flags | Ciclo |
| **Cambiar la interfaz congelada** | **Nadie** — es evento de vuelta a la puerta | — |

**Esto no debilita el TDD, le acota el espacio de búsqueda.** Las Tres Leyes
siguen intactas. El DDR no escribe código: dice dónde vive y qué firma tiene. Cada
línea de producción sigue necesitando un test rojo que la pida.

Lo que sí cambia: el `tdd_craftsman` deja de decidir *dónde* vive el código. Esa
autonomía era la que producía la incoherencia entre features.

---

## 3. El pipeline propuesto

Fase nueva `design_partner`, entre el Gherkin y el TDD:

```
pending
  → spec_partner        → project-spec.md
  → gherkin_author      → features/<name>.feature          [spec_ready]
  → design_partner      → docs/design/DDR-<id>-<slug>.md    [design_ready]
  → ⏸ PUERTA HUMANA (una sola): escenarios + opciones de diseño juntos
  → in_progress
  → tdd_craftsman       (con INTERFAZ CONGELADA en el prompt)
  → judge               (+ diff contra el DDR + lente de red flags)
  → mutation_tester
  → done
```

### Por qué el diseño va después del Gherkin

Tres razones que apuntan al mismo lado:

1. Ousterhout ubica el diseño después de que la spec está cerrada
   (`integracion-sdd.md:10`).
2. Los escenarios son el insumo que hace **evaluable** el "diseñarlo dos veces".
   La opción A y la B se comparan por el costo del requerimiento futuro concreto
   (`SKILL.md:135`: *"nombrá el requerimiento concreto, no «si escala»"*). Sin
   escenarios no hay con qué cotizar.
3. Primero el QUÉ, después el CÓMO. Mezclarlos hace que la discusión de diseño
   contamine el contrato de comportamiento.

### Una sola parada, fusionada

El `design_partner` corre sobre los escenarios **borrador**, y el lead presenta
ambas cosas en el mismo mensaje: firmas el QUÉ y el CÓMO de una vez.

**Fundamento:** la puerta humana es el recurso más escaso del arnés — su latencia
se mide en días, no en tokens. Duplicarla es el modo más probable de que la fase
de diseño se empiece a saltear, que es exactamente el fracaso que la skill se
autodiagnostica en `integracion-sdd.md:59`: *"si clasificás todo como
estructural, la skill se vuelve un impuesto y vas a terminar salteándola"*. Además
preserva la regla dura vigente de `craftsman_lead.md:138` ("una sola puerta de
aprobación humana").

**Esto cambiaría si:** el `design_partner` empieza a producir DDRs que quedan
inválidos porque el humano cambió escenarios en la puerta, en más de ~1 de cada 4
features. Ahí conviene secuenciar: aprobar escenarios primero, diseñar después.

**Throttle interno:** el PASO 0 de la skill (carriles trivial / estándar /
estructural, `SKILL.md:55-59`). Solo el carril **estructural** presenta opciones
para elegir. En trivial y estándar el DDR se registra como `aplicado por defecto`
y la puerta muestra solo los escenarios, como hoy.

### Formato de la parada fusionada

```markdown
## Escenarios — features/<name>.feature
@s1 … @s2 … @sec1 …

## 🚪 PUERTA DE DISEÑO — <título>     ← solo si carril = estructural
**Decisión requerida:** <una línea>
**Irreversible si:** <qué se vuelve caro de deshacer>

### Opción A — … / ### Opción B — …
(idea · interfaz · qué oculta · costo hoy · costo 6-12m · reversibilidad)

| Criterio | A | B |
| Superficie expuesta | | |
| Carga cognitiva del consumidor | | |
| Costo de la feature futura <X> | | |
| Costo de revertir | | |

### ✅ Recomendación: <opción>
**Fundamento:** <atado al diagnóstico, no a preferencia estética>
**Esto cambiaría si:** <condición concreta>

→ Respondé: "aprobado + A"
```

El formato largo está en `SKILL.md:146-182`; hay una versión corta para carril
estándar en `puerta-humana.md:101-115`.

---

## 4. El modo apagable

Hay proyectos —cargas puntuales, scripts de un solo uso— donde la fase de diseño
es sobreingeniería mientras el resto del arnés sigue valiendo. El carril throttlea
la **puerta**, no la **fase**: aun clasificando todo como trivial se paga una
corrida de Opus por feature para concluirlo. Hace falta un interruptor por encima.

### Dónde vive el interruptor

**En `feature_list.json`, no en `harness.config.sh`.** El reparto actual del
conocimiento es nítido y hay que respetarlo:

- `harness.config.sh:12-72` — **todo es stack**: lenguaje, rutas, comandos de
  test/mutación/build. Ni una variable de proceso.
- `feature_list.json:4-17` (`rules`) — **todo es proceso**:
  `one_feature_at_a_time`, `require_tests_to_close`,
  `require_approved_spec_to_implement`, y ya existe `sdd_required_when:15`.

El modo diseño es proceso. Ponerlo en `harness.config.sh` sería un error de
ocultamiento de información en el diseño de la propia integración.

No es solo estética: ubicarlo bien **elimina cinco enganches** — `profiles/*.sh`
(×5), `install.sh --migrate`, el fallback de `unset` en `init.sh:23-45` y la
migración de instalaciones existentes. `feature_list.json` ya es estado por
proyecto y ya lo parsea `init.sh:67-129`.

### Forma

```jsonc
"rules": {
  …
  "design_default": true,          // ← default del proyecto
  "design_required_when": "feature has \"design\": true (hereda design_default si falta)"
},
"features": [
  { "id": 12, …, "sdd": true, "design": false, "status": "pending" }
]
```

- **Default `true`.** Un flag default-off es un flag que nadie enciende nunca. El
  arnés entero está construido sobre gates duros que se apagan a propósito, no por
  omisión.
- **Dos valores, no cuatro.** Un `light` (correr la fase sin abrir puerta nunca)
  ya es lo que hace el carril `estándar`. Un tercer valor sería un flag que existe
  porque nadie quiso decidir — red flag #4, sobreexposición
  (`red-flags.md:66-72`), en la configuración de la skill que trata sobre el red
  flag #4.
- **Precedencia:** `feature.design` (si existe) > `rules.design_default` > `true`.
  Con la fase encendida, el carril decide la puerta.

### Qué apaga exactamente `off`

| | Coste real | ¿Se apaga? |
|---|---|---|
| La fase `design_partner` | 1 corrida Opus + latencia humana si es estructural | **Sí** — es lo caro |
| La puerta de diseño | Ya la throttlea el carril | Redundante |
| **La lente de red flags en el `judge`** | **Cero corridas extra** — es un paso dentro de una que ya ocurre | **Nunca** |

La lente no se apaga jamás. `red-flags.md:140` dice que el comentario que repite
el código *"es el más frecuente en código generado por LLM. Al revisar output de
subagentes, buscalo primero"* — y este arnés genera **todo** su código con LLMs.
Apagarla en un proyecto desechable no ahorra nada (el `judge` ya es Opus y ya lee
el diff) y te quita lo único que era gratis. Mismo patrón que `threat-lens` en
`judge.md:39-45`: corre siempre, devuelve cero hallazgos si no aplica.

El modo apaga **la fase** de diseño, no **la lente** de diseño.

### Visibilidad: por qué el default se escribe en la entrada

Un flag global enterrado es invisible en el momento de la decisión, y nadie lo
revisita. "Este proyecto es descartable" es la decisión razonable-que-envejece-mal
por excelencia: el script de un solo uso que vive seis años.

`"design": false` escrito en cada entrada es visible cuando abrís
`feature_list.json` para agregar la feature #12. Es la diferencia entre oscuridad
y obviedad — PASO 7 y red flag #14. `"sdd": true` ya está en cada entrada, así que
el precedente dice que ese ruido es aceptable.

### El ejemplo que conviene no usar

El caso intuitivo "un ETL no necesita esto" es justo el equivocado.
`red-flags.md:54-62` tiene una nota con nombre propio para ETL: descomposición
temporal, `leer → validar → transformar → escribir`, *"la fábrica más productiva
de filtración de información"*. Y aclara que en un ETL las etapas temporales **sí
son reales** — la corrección no es eliminarlas, es que **ninguna etapa conozca el
esquema por su cuenta**.

Un ETL desechable con el esquema parseado en cuatro etapas es el caso canónico de
amplificación de cambios. Por eso `off` no es silencio total: el proyecto corre en
`off` y no paga nada, pero la feature que define el esquema se marca
`"design": true`. Es la única que iba a doler.

### La prueba de que el modo no agrega un eje

El kit ya carga cinco ejes de configuración: `active_profile`, `"sdd"`, el prefijo
`[REFACTOR]`, `init.sh --fast` vs completo, e intensidad de `ponytail`. Un sexto
eje independiente sería complejidad real — red flag #4 al nivel del arnés mismo.

`"design"` al lado de `"sdd"` en el mismo objeto, gobernado por una regla al lado
de `sdd_required_when`, **extiende un eje existente** en vez de crear uno. Esa es
la prueba, y la pasa solo en esta ubicación.

---

## 5. Cómo esto ataca la amplificación de cambios

Cuatro mecanismos concretos:

### 5.1 DDR por módulo, no por feature

Varias features comparten un DDR. Antes de abrir puerta, el lead busca en
`docs/design/` una decisión que ya cubra el módulo — `puerta-humana.md:26`: *"Ya
existe un DDR aprobado que cubre este caso: citalo y seguí"*.

Así la feature #7 **hereda** la interfaz congelada en vez de inventar la séptima
abstracción del mismo concepto. Requiere un `docs/design/INDEX.md` (módulo → DDR →
estado) para que la búsqueda sea una lectura y no un glob.

### 5.2 El costo a 6-12 meses se ancla en `feature_list.json`

La skill exige nombrar el requerimiento futuro **concreto** (`SKILL.md:135`). En
un proyecto genérico eso es información que solo tiene el humano — por eso
`integracion-sdd.md:45` la manda a preguntar en la puerta.

**Este arnés tiene el roadmap en disco**: las features `pending`. El
`design_partner` cotiza cada opción contra ellas literalmente:

> *"La opción B deja el formato de fecha en dos lugares. La feature #9
> (`exportar_reporte_mensual`, pending) va a necesitar el mismo formato: con B son
> tres lugares. Con A queda en uno."*

Es una ventaja que la skill genérica no puede tener, y es el argumento más fuerte
de toda la integración.

### 5.3 El `judge` mide amplificación observada contra la predicha

El mapa `covers:` y `tools/test-map.sh` ya dicen qué módulos tocó la feature. Si
el DDR predijo 2 módulos afectados y el diff tocó 5, eso es drift **medible** — y
le da una línea base al smell de "módulo dios" que `judge.md:36-38` hoy juzga a
ojo.

### 5.4 La interfaz congelada viaja en el prompt del `tdd_craftsman`

Plantilla lista en `integracion-sdd.md:102-129`. Lo importante es el corolario: si
la interfaz no se puede implementar razonablemente, el craftsman **frena y
reporta** (`status: partial`) — no improvisa. `integracion-sdd.md:29`: *"eso es un
evento de vuelta a la puerta, no una licencia para improvisar"*.

Esto encaja sin fricción en el Gatekeeper existente (`craftsman_lead.md:217-250`),
que ya sabe qué hacer con un `partial`.

---

## 6. Qué puede y qué NO puede verificar el arnés

En este arnés solo lo que es un `@s` llega a tener test, y solo lo que tiene test
pasa por mutación. **Una decisión de diseño no es comportamiento observable** —
por definición un refactor lo preserva. Por lo tanto la mutación **no puede**
validar un diseño, y hay que decirlo antes de que alguien suponga lo contrario:

| Artefacto APOSD | Quién lo verifica | Fuerza del gate |
|---|---|---|
| Interfaz congelada | `judge`: diff firma-en-DDR vs firma-en-código | **Fuerte** — mecánico, binario |
| Invariantes del DDR | Un test que los afirme; `judge` verifica | Fuerte si el invariante es observable |
| Nº de módulos tocados vs predicho | `judge` + mapa `covers:` | Fuerte — es un conteo |
| Red flags de severidad alta | `judge`, por inspección | Medio — es juicio |
| Red flags de severidad baja | `tdd_craftsman` en el paso Refactor | Débil — higiene |
| *"Es el diseño más simple posible"* | **Nadie** | **Nulo por diseño** |

Esa última fila es la justificación de que la puerta humana exista. Si el arnés
pudiera verificarlo, no haría falta preguntarte.

---

## 7. Convivencia con las skills que ya están

### `ponytail` — tensión real, árbitro claro

YAGNI vs invertir 10-20% estratégico. El árbitro es el carril: en **trivial** gana
ponytail sin discusión. En **estructural**, el PASO 6 de APOSD ya incorpora YAGNI
(`SKILL.md:202`: *"somewhat general-purpose"*, *"la generalidad no pedida es
deuda, no seguro"*), y su lista de autocorrección (`SKILL.md:257-262`) es
literalmente ponytail aplicado a APOSD.

Regla dura necesaria, en espejo de la que `threat-lens` ya tiene
(`ponytail/SKILL.md:47-48`): **`ponytail` no borra una interfaz congelada por un
DDR aprobado.** Puede proponer cambiarla, y eso es volver a la puerta.

### `ponytail-review` vs la lente APOSD en el `judge`

Ejes distintos, hay que deslindarlos o se pisan: `ponytail-review` busca qué
**borrar** (código de más); APOSD busca si el módulo **expone de más o esconde de
menos** (superficie). Un módulo puede ser mínimo en líneas y pésimo en superficie.

### `threat-lens` — complementario, con dos interacciones no obvias

1. **Un `@sec` puede forzar una interfaz.** Si el escenario de abuso exige que el
   check de ownership viva *dentro* del módulo y no en el llamador, eso restringe
   las opciones de diseño. El `design_partner` debe leer el `.feature` **con sus
   tags `@sec`**, no solo los `@s` funcionales.
2. **"Definir errores fuera de existencia" no se aplica a fallas de seguridad.**
   `SKILL.md:109` propone redefinir la semántica para que el caso deje de ser
   error (borrar algo que no existe = éxito). Aplicar eso a "no autorizado" es una
   vulnerabilidad, no una simplificación. Es la excepción explícita al PASO 3 y
   tiene que estar escrita.

---

## 8. Workflow A — proyecto nuevo

### DDR-000: el esqueleto, antes de la primera feature

En greenfield, si el reparto de módulos no se decide una vez, la **feature 1 lo
decide por accidente** y las features 2..N heredan ese accidente. Es la forma más
barata de arruinar un proyecto nuevo.

Propuesta: después de la primera conversación de spec y antes de la primera
feature, un DDR de esqueleto que decida los límites de módulo del sistema. Ese DDR
es el que después llena `docs/architecture.md` — que hoy es una plantilla con
`TODO:` que `harness_bootstrap` completa a ciegas, sin haber visto todavía ni una
línea del dominio.

### Recorrido por feature

| Fase | Qué cambia |
|---|---|
| `spec_partner` | Detecta decisiones de diseño encubiertas como requisitos: la spec nombra tablas, formatos o clases, o describe el orden de los pasos internos (`integracion-sdd.md:20`). Las convierte en preguntas, no las acepta como dadas |
| `gherkin_author` | Sin cambios |
| **`design_partner`** | Clasifica carril → diagnóstico → profundidad de módulos → diseñarlo dos veces → DDR con interfaz congelada y tareas derivadas |
| ⏸ Puerta | Escenarios + opciones, una sola parada |
| `tdd_craftsman` | Recibe la interfaz congelada como contrato cerrado. TDD estricto dentro de ella |
| `judge` | + diff contra el DDR + lente de red flags + módulos tocados vs predichos |
| `mutation_tester` | Sin cambios |

### Cómo se ve el carril en la práctica

- **Trivial** — añadir un campo opcional a un DTO que ya existe; corregir un
  cálculo dentro de una función. Sin DDR, tres líneas de justificación.
- **Estándar** — un validador nuevo consumido por un solo endpoint. DDR corto,
  `aplicado por defecto`, sin puerta.
- **Estructural** — el primer módulo que persiste algo; un contrato entre dos
  servicios; el formato de un mensaje; cualquier interfaz que una segunda feature
  vaya a consumir. DDR completo y puerta.

Ante duda entre estándar y estructural, **estructural** (`SKILL.md:61`): el costo
es asimétrico.

---

## 9. Workflow B — refactor de proyecto en producción

El kit ya tiene `docs/refactoring.md`: caracterización Gherkin como red de
seguridad, refactor en verde, mutación como prueba de que la red muerde, entradas
`[REFACTOR]` en `feature_list.json`. Todo eso sigue igual y es bueno.

**Lo que falta es cómo decidir QUÉ refactorizar y en qué orden.** Hoy eso lo pone
el humano a ojo, y `docs/refactoring.md:34-42` ("divide por seam") asume que ya
sabés cuáles son los seams. Ese es el hueco que llena APOSD.

### Fase de auditoría (una sola vez por proyecto, ortogonal al modo)

Un proyecto con `design_default: false` **igual puede correr la auditoría**: no es
una fase del pipeline, es una invocación puntual.

#### Paso 1 — Barrido con `Explore` en paralelo

Cada agente con una pregunta acotada mapeada a un red flag detectable por lectura:

| Pregunta | Red flag | Detector |
|---|---|---|
| ¿Qué conocimiento está duplicado? | #2 Filtración | *"si mañana cambio el formato de X, ¿cuántos archivos toco?"* (`red-flags.md:46`) |
| ¿Hay módulos cortados por orden de ejecución? | #3 Descomposición temporal | `leer/validar/transformar/escribir` como clases separadas que conocen el mismo esquema |
| ¿Qué firmas públicas tienen >4 params o flags booleanos? | #4 Sobreexposición | Lectura de firmas |
| ¿Qué nombres son `data`/`info`/`manager`/`utils`/`process`/`handle`? | #12 Nombre vago | Un `grep`, es lo más barato del barrido |
| ¿Qué módulos tienen interfaz grande sobre implementación chica? | #1 Somero | Ratio métodos públicos / líneas útiles |

#### Paso 2 — Evidencia dura de git, gratis y sin herramientas

Esto es lo que convierte la auditoría en evidencia y no en opinión — el principio
`SKILL.md:244`, *"evidencia sobre adjetivos"*:

- **Churn** — `git log --format= --name-only | sort | uniq -c | sort -rn`: qué
  archivos se tocan más. **Churn × severidad de red flag = el hotspot real.** Es
  la operacionalización directa de `red-flags.md:190`, priorizar *"por cuánto
  cuesta el próximo cambio, no por cuántos hay"*. Un red flag alto en un archivo
  que nadie toca hace tres años no es una prioridad.
- **Co-change** — archivos que cambian juntos en el historial **sin importarse
  entre sí**. Eso es amplificación de cambios **medida**, no opinada: literalmente
  la definición del síntoma (`SKILL.md:73`), calculada desde el historial. Es el
  detector de filtración de información más confiable que hay, y no necesita
  ninguna herramienta.

#### Paso 3 — `docs/complejidad.md`

Tabla rankeada, una fila por hotspot: síntoma · evidencia (`archivo:línea` + nº de
co-cambios) · red flag y severidad · cuál es el próximo cambio que se vuelve caro.

Cierra con la frase que la skill exige (`SKILL.md:82`): *"El cambio más caro que
este diseño va a tener que absorber en los próximos 6 meses es ___, y hoy cuesta
___."*

#### Paso 4 — Puerta humana de priorización

El humano elige los 3 hotspots a atacar. El ranking técnico no reemplaza al
roadmap: qué módulo va a recibir features el próximo trimestre es información que
solo tiene él (`puerta-humana.md:5`).

#### Paso 5 — Un DDR por hotspot

Diseñarlo dos veces sobre la pregunta *"¿dónde debería vivir este conocimiento?"*.
Salida: **interfaz objetivo congelada** + el orden de los movimientos.

Anti-big-bang, del propio formato: una decisión = un DDR = **una página**; si no
entra, son dos decisiones y hay que partirla (`plantilla-ddr.md:5`).

#### Paso 6 — Traducción a `feature_list.json`

Cada movimiento hacia la interfaz objetivo es una entrada `[REFACTOR]` — la
plantilla ya existe en `docs/refactoring.md:92-113`. El DDR aporta lo que hoy
falta: **la interfaz destino explícita** y **el orden**.

### El orden correcto para legacy

```
auditoría → DDR (interfaz objetivo) → caracterización ACOTADA AL SEAM
          → mover en verde → judge → mutación
```

El DDR va **antes** de la caracterización, y esto matiza `docs/refactoring.md:56`:
es el DDR el que te dice **qué** comportamiento hay que pintar. Caracterizar antes
de saber dónde va a caer el seam te hace escribir tests de más, sobre código que
va a desaparecer.

### Dos notas operativas

- **Coste de mutación.** La mutación sobre un módulo legacy grande es brutal en
  CPU. `HARNESS_FEAT_SCOPE` y el mapa `covers:` ya existen para acotarla —
  usarlos no es opcional acá.
- **SonarQube, más adelante.** Cuando los proyectos estén evaluados, sustituye el
  Paso 1 (barrido de lectura) por medición: complejidad cognitiva, duplicación,
  hotspots por archivo. El Paso 2 (git) y todo lo demás quedan igual. La
  auditoría está diseñada para que Sonar sea una capa de evidencia intercambiable,
  no una dependencia.

---

## 10. Adaptaciones que la skill necesita

Sección `## Precedencia del Craftsman Harness` al principio del SKILL.md — el
patrón ya establecido con que el kit aterriza skills de terceros
(`ponytail/SKILL.md:26-52`, `ponytail-review/SKILL.md:19-28`). Contenido mínimo:

1. Mapeo de vocabulario spec-kit → fases del arnés.
2. Carril → puerta: solo estructural abre; y el modo `design` puede apagar la fase
   entera, pero **nunca** la lente del `judge`.
3. La interfaz congelada **no exime del TDD**: las Tres Leyes siguen.
4. `arch-review` no existe acá: las decisiones de infraestructura escalan al
   humano, no a una skill inexistente.
5. Excepción de seguridad al PASO 3 (no definir fuera de existencia una falla de
   autorización).
6. No emitir el bloque YAML `design_gate`.
7. Normalizar el vocabulario de `Estado` y de los carriles.

---

## 11. Mapa de enganches

Según el patrón del commit `5125a43` (`threat-lens`) para skill transversal, más
lo propio de una fase nueva.

### La skill

| # | Archivo | Qué |
|---|---|---|
| 1 | `.claude/skills/aposd-design/{SKILL.md,references/*,assets/*}` | Copiar + sección de precedencia |
| 2 | `install.sh` (`SKILL_FILES`) | Cada archivo, uno por uno, o no se propaga |
| 3 | `AGENTS.md:55` | Fila en la tabla de skills |

### La fase nueva

| # | Archivo | Qué |
|---|---|---|
| 4 | `.claude/agents/design_partner.md` | Agente nuevo. Tools: `Read, Write, Edit, Glob, Grep, Bash`. Regla dura: solo escribe en `docs/design/**` |
| 5 | `install.sh` (`AGENT_FILES`) | Registrarlo |
| 6 | `model-map.yaml:48-56` | `design_partner: deep`. Y `channel=agent` **siempre**, igual que `spec_partner` y `judge` — mismo argumento de `docs/model-fit.md`: es fase de juicio, abaratarla contamina todo aguas abajo |
| 7 | `craftsman_lead.md:48-58, :143-153, :164-198, :217-250` | Tabla de invocación, diagrama, Casos A-D, y qué espera el Gatekeeper de esta fase |
| 8 | `docs/workflow.md:10-34, :92-103` | Diagrama y mapa de artefactos |
| 9 | `AGENTS.md:54, :76-103` · `CLAUDE.md:36-47` | Fila de agentes y pipeline numerado |
| 10 | `CHECKPOINTS.md` | Criterio C nuevo: la interfaz congelada se respetó |
| 11 | `judge.md` (paso nuevo + sección del veredicto + regla dura) | Lente APOSD, en espejo de cómo entró `threat-lens` en `:39-45`, `:85-88`, `:116-117` |
| 12 | `tdd_craftsman.md` + `.opencode/agents/tdd_craftsman.md` | Bloque de interfaz congelada. El espejo opencode es obligatorio: esos agentes **no tienen la tool `Skill`** y leen por path |
| 13 | `progress-log/SKILL.md:33-41` | El DDR es un artefacto nuevo |
| 14 | `init.sh:67-129` | Si una feature referencia un DDR, el archivo debe existir — en espejo de la validación de `.feature` |

### El modo

| # | Archivo | Qué |
|---|---|---|
| 15 | `feature_list.json:4-17` | `rules.design_default` + `rules.design_required_when` + campo opcional `design` en las entradas |
| 16 | `craftsman_lead.md` | El punto donde se salta la fase |

`harness.config.sh`, `profiles/*.sh` e `install.sh --migrate`: **no se tocan**.

### Coste

+1 corrida Opus por feature estructural. Medible en el banco A/B que
`docs/model-fit.md:66-96` ya tiene montado — conviene registrar ahí las primeras
diez features con la fase encendida antes de dar el diseño por bueno.

---

## 12. Cómo vas a saber que esto salió mal

Señales concretas de que la integración se convirtió en el impuesto que la skill
advierte:

- Empezás a marcar features como `"design": false` para no esperar la puerta.
- Los DDRs presentan opciones que comparten la misma interfaz pública — eso no es
  diseñar dos veces, es escribir tres párrafos (`SKILL.md:121`).
- El `design_partner` tarda más que implementar la opción más simple
  (`SKILL.md:261`).
- Aparecen DDRs de más de una página.
- El `judge` nunca encuentra drift contra el DDR. O el diseño es perfecto, o nadie
  está mirando.

El contra-síntoma de que salió bien es uno solo y es medible: **la feature N+1
sobre un módulo con DDR toca menos archivos que las que se hicieron sin él.** Con
el mapa `covers:` eso se cuenta, no se opina.
