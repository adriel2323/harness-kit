---
name: threat-lens
description: >
  Lente de seguridad para el pipeline SDD del Craftsman Harness. Traduce la
  Guía de Buenas Prácticas de Seguridad del equipo a dos artefactos que el
  arnés SÍ puede verificar: escenarios de abuso `@sec` en el `.feature`
  (que el `tdd_craftsman` convierte en tests y la mutación valida) y una
  lista de checks de inspección para el `judge`. Selecciona los controles
  según el stack detectado (frontend, backend/API, datos/DBA/analytics,
  supply chain/CI, IA). Usar en dos momentos: modo `spec` al conversar la
  spec y destilar escenarios (`spec_partner` / `gherkin_author`), y modo
  `review` en el veredicto del `judge`. Úsala también si alguien dice
  "threat model", "modelo de amenazas", "casos de abuso", "STRIDE",
  "revisión de seguridad", "OWASP", "IDOR", "inyección", o si la feature
  toca autenticación, autorización, dinero, PII, uploads, queries a DB,
  llamadas HTTP salientes o prompts de IA. NO la uses para features sin
  frontera de confianza (formateo de salida, refactor puro interno).
argument-hint: "[spec|review] [--perfil=frontend,backend,datos,supply,ia]"
---

# Threat Lens

> "¿Cómo puede abusarse de esto?" debe ser el **primer** diseño, no el último.
> — Principio 5 de la guía de seguridad del equipo.

## Por qué en el pipeline y no en un escaneo al final

En este arnés **solo lo que es un escenario `@s` llega a tener un test**, y
solo lo que tiene un test pasa por mutación. Un control de seguridad que no
es escenario no existe: no lo pide ningún rojo (Ley 1 del TDD), el `judge` no
tiene qué exigir y el `mutation_tester` no tiene qué morder. Un escaneo
posterior encuentra el agujero cuando la feature ya está `done` y el contrato
aprobado no lo contempla — es decir, tarde y fuera de la puerta humana.

Por eso esta skill tiene **dos puntos de inserción**, y el primero es el que
más rinde:

| Momento | Quién la invoca | Qué produce | Qué la valida después |
|---|---|---|---|
| **`spec`** — al conversar la spec y destilar el `.feature` | `spec_partner`, `gherkin_author` (vía `craftsman_lead`) | Escenarios de abuso taggeados `@sec` + `@sN` en `features/<name>.feature` y una sección **Amenazas** en `project-spec.md` | El humano en la puerta; luego `tdd_craftsman` (test por `@s`), `judge` (cobertura), `mutation_tester` (que el test muerde) |
| **`review`** — en el veredicto | `judge` | Bloque `## Seguridad` en `progress/judge_<name>.md`: `@sec` faltantes + hallazgos de inspección con `archivo:línea` | El `craftsman_lead` (Gatekeeper) al leer `status: partial` |

El modo `spec` es el que **suple el porcentaje grande** de la guía: convierte
prácticas en contrato ejecutable. El modo `review` es la red de seguridad para
lo que **no es expresable** como Given/When/Then (headers, flags de cookie,
secretos, CVEs, Dockerfile).

---

## Triage: las tres cubetas

Ante cualquier práctica de la guía, decide primero en qué cubeta cae. Es la
decisión más importante de la skill; equivocarla produce teatro.

**Cubeta A — Escenario `@sec`.** El control tiene **comportamiento observable
desde el borde del sistema**: un código de retorno, un mensaje, un efecto
ausente. Se escribe como Gherkin y va al `.feature`.
→ authz/IDOR, inyección (SQL/NoSQL/comando/SSTI), validación de esquema,
rate limiting, error disclosure, lógica de negocio (precio, cupón, stock),
CSRF, SSRF, uploads, open redirect, path traversal, deserialización, XXE,
límites de payload/nesting, idempotencia, RLS multi-tenant, masking de PII en
exports, validación de output de IA.

**Cubeta B — Check de inspección.** El control vive en **configuración,
dependencias o forma del código**, no en comportamiento de la feature. No se
puede exigir con un `Then` sin inventar un test-espejo de la config. Va al
modo `review` como grep/comando con veredicto citable.
→ headers de seguridad, CSP, flags de cookie, SRI, secretos hardcodeados,
CVEs de dependencias, lockfile, `rel=noopener`, container como root, TLS,
permisos de cuentas de DB, cipher suites, `.env` en git.

**Cubeta C — Fuera del arnés.** Depende de infraestructura corriendo, de
proceso organizacional o de terceros. **Nómbrala una vez y déjala fuera** —
no simules cobertura.
→ red team, respuesta a incidentes, HSM, WAF/DDoS, quarterly access review,
DAM/SIEM, pentest, backups y restore, hardening de OS/K8s, mTLS entre
servicios, política de uso de IA del equipo.

> Regla: si no sabes escribir el `Then` medible, no es Cubeta A. Un escenario
> tipo `Then el sistema es seguro` es peor que no tenerlo: pasa la puerta,
> genera un test vacío y le da al equipo una falsa señal verde.

---

## Paso 0 — Detectar el perfil del stack

Si el usuario pasó `--perfil=...`, respétalo. Si no, deriva de disco (barato,
una sola pasada):

| Señal | Perfil |
|---|---|
| `HARNESS_LANGUAGE` en `harness.config.sh` | base del lenguaje (payloads y libs) |
| `package.json` con react/vue/svelte/angular/next, `index.html`, `*.tsx`, `*.vue` | `frontend` |
| rutas/handlers HTTP (`express`, `fastapi`, `flask`, `gin`, `axum`, `spring`), `openapi.*`, `routes/`, `controllers/` | `backend` |
| SQL crudo, ORM, migraciones, `*.sql`, `dbt/`, `airflow/`, notebooks `.ipynb`, `pandas`/`polars`/`spark` | `datos` |
| **siempre** (todo repo tiene dependencias y CI) | `supply` |
| `anthropic`/`openai`/`langchain`/`ollama` en manifiestos, o prompts en el código | `ia` |

Un repo puede tener varios perfiles a la vez (fullstack = `frontend` +
`backend` + `supply`). **Carga solo los `references/` de los perfiles activos**
— divulgación progresiva, igual que `AGENTS.md`.

| Perfil | Referencia |
|---|---|
| `frontend` | `references/frontend.md` |
| `backend` | `references/backend.md` |
| `datos` | `references/datos.md` |
| `supply` | `references/supply-chain.md` |
| `ia` | `references/ia.md` |
| payloads para los `Given`/`When` | `references/payloads.md` |

---

## Modo `spec` — derivar escenarios de abuso

**Entrada:** la feature en curso (`feature_list.json`), su sección de
`project-spec.md` si existe, y el perfil detectado.
**Salida:** escenarios `@sec` propuestos + sección `## Amenazas` para el spec.

### Protocolo

1. **Traza la frontera de confianza de ESTA feature.** ¿De dónde entra dato
   que no controlas? (request HTTP, formulario, CSV, argv, webhook, respuesta
   de un tercero, output de un LLM). Si la feature no cruza ninguna frontera
   de confianza — formateo interno, refactor puro, cálculo sobre datos ya
   validados — **dilo en una línea y no propongas nada**. Cero escenarios es
   un resultado válido y frecuente.

2. **Pasa STRIDE, pero solo sobre esa frontera.** Una pregunta por letra,
   descartando rápido lo que no aplica:
   - **S**poofing — ¿quién puede hacerse pasar por otro aquí?
   - **T**ampering — ¿qué campo del request cambia el resultado si lo edito?
   - **R**epudiation — ¿queda registro de quién lo hizo?
   - **I**nformation disclosure — ¿qué se filtra en la respuesta o el error?
   - **D**enial of service — ¿qué input caro puedo mandar en bucle?
   - **E**levation of privilege — ¿cómo llego a algo que no me toca?

3. **Selecciona controles del `references/` del perfil.** Cada tabla trae
   `Control → Riesgo → Cubeta → plantilla de escenario`. Toma solo los que
   la frontera del paso 1 realmente expone.

4. **Presupuesto: 2–5 escenarios `@sec` por feature.** No dispares treinta.
   Prioriza en este orden: **(1)** authz/ownership del recurso que toca la
   feature, **(2)** la inyección propia de su sink (SQL si consulta, comando
   si ejecuta, HTML si renderiza, HTTP si sale a la red), **(3)** validación
   de límites del input, **(4)** qué filtra el error. Si sobra presupuesto,
   lógica de negocio abusable.

5. **Escríbelos en Gherkin** con la convención de abajo y entrégalos al
   `gherkin_author` (o escríbelos tú si eres él). Añade al `project-spec.md`
   una sección `## Amenazas` con: amenaza → control → cubeta. Las de Cubeta B
   y C van ahí **listadas explícitamente como no cubiertas por tests**, para
   que el humano decida en la puerta.

6. **Para.** Los `@sec` son escenarios como cualquier otro: entran a la
   **misma puerta de aprobación humana**. No los cueles después.

### Convención Gherkin para `@sec`

- Doble tag: **`@s<N>` (numeración estable, la que exige el `judge`) + `@sec`**.
  Mismo patrón que `@characterization` en modo refactor.
- Título en forma de abuso, no de deseo: `Abuso: <actor> intenta <acción>`.
- El `Then` afirma **lo que NO pasa**, de forma medible: código de retorno,
  cuerpo que no contiene el dato, registro ausente, contador que no cambió.
- Un `And` extra para el canal de error cuando aplique (código + que el
  mensaje no filtre interno).

```gherkin
  @s7 @sec
  Scenario: Abuso: un usuario pide el pedido de otro usuario
    Given un usuario autenticado "ana" con el pedido 100
    And un usuario autenticado "beto" sin pedidos
    When "beto" solicita el pedido 100
    Then la respuesta tiene código 404
    And el cuerpo no contiene el email de "ana"

  @s8 @sec
  Scenario: Abuso: comilla simple en el filtro de búsqueda
    Given existen 3 clientes
    When se busca clientes con el término "' OR '1'='1"
    Then el resultado tiene 0 clientes
    And no se lanza ningún error de base de datos

  @s9 @sec
  Scenario: Abuso: el precio llega manipulado en el request
    Given un artículo con precio 100 en el catálogo
    When se envía una orden de ese artículo con precio 1
    Then la orden se registra con precio 100
```

Fíjate en el patrón del tercero: el control no se prueba mirando el código,
se prueba **por el efecto**. Ese es el escenario que sobrevive a un refactor
y el que la mutación puede matar.

### Nota para `spec_partner`

Cuando converses la spec, mete estas dos preguntas en la ronda (son de
producto, no de mecánica, así que caben en tu taxonomía):

- *"¿Quién NO debería poder hacer esto, y qué pasa si lo intenta?"* → sale
  el escenario de authz sin discutir implementación.
- *"Si un usuario manda este campo con basura o con un valor que no le
  corresponde, ¿qué queremos que pase exactamente?"* → sale el contrato de
  validación y el de error.

Registra la respuesta como **decisión** en `project-spec.md`. Si el humano
dice "eso no aplica acá", eso también es una decisión: escríbela con su razón.

---

## Modo `review` — checks para el `judge`

**Entrada:** el diff de la feature, su `.feature`, el perfil detectado.
**Salida:** un bloque `## Seguridad` para `progress/judge_<name>.md`.

### Protocolo

1. **Cobertura `@sec`.** Si el perfil exige un control de Cubeta A que la
   feature claramente cruza y **no hay escenario `@sec`** que lo cubra, es un
   hallazgo **BLOQUEANTE**: el contrato está incompleto y toca volver al
   `gherkin_author` + puerta humana, no parchear en el TDD.
2. **Cada `@sec` tiene test real.** Aplica el mismo criterio que el resto de
   la cobertura del `judge`: `@s ↔ test` concreto. Un test que pasaría aunque
   borres el control **no cuenta** — dilo y déjaselo al `mutation_tester`
   como riesgo explícito.
3. **Checks de Cubeta B**, con los comandos del `references/` del perfil. Solo
   sobre archivos que **esta feature tocó** — no auditorías del repo entero;
   ese no es tu trabajo y ahoga el veredicto.
4. **Emite el bloque.** Solo hallazgos con `archivo:línea` o con `@s` faltante.
   Nada de "considerar revisar la seguridad de X".

### Formato de salida

Se inserta como sección propia en `progress/judge_<name>.md`, entre
`## Calidad` y `## Checkpoints`:

```markdown
## Seguridad (threat-lens, perfil: backend+supply)

**Cobertura @sec**
- @s7 IDOR pedidos: [x] cubierto por `test_pedido_ajeno_404`
- authz en `DELETE /ordenes/{id}`: [ ] ← BLOQUEANTE, sin escenario en el .feature

**Inspección**
- BLOQUEANTE ordenes/repo.py:42 — query por f-string con `user_input`. Parametriza.
- OBSERVACIÓN api/errores.py:18 — el handler devuelve `str(exc)` al cliente.

**Fuera de alcance del arnés (Cubeta C)**
- WAF, rotación de credenciales de DB — no verificables desde aquí.

net: 1 bloqueante, 1 observación.
```

### Cómo pesa en el veredicto del `judge`

- **BLOQUEANTE** → el `judge` emite `CHANGES_REQUESTED` / `status: partial`.
  Solo es bloqueante si es citable y demostrable: un sink sin parametrizar,
  un endpoint sin check de ownership, un secreto en el diff, un `@sec` que el
  perfil exige y no existe.
- **OBSERVACIÓN** → se anota, no bloquea. Va a `risks` del bloque de 4 líneas.
- Si no hay nada: `Sin hallazgos de seguridad en el diff.` y sigue.

---

## Reglas duras

- ❌ **No inventes alcance.** Un `@sec` nuevo sobre una feature ya aprobada
  no se cuela en el TDD: vuelve al `.feature` y a la puerta humana. La única
  excepción es un **BLOQUEANTE de Cubeta B en el diff** (secreto hardcodeado,
  query concatenada), que es un defecto del código escrito, no alcance nuevo.
- ❌ **No hagas teatro.** Si no puedes escribir el `Then` medible, es Cubeta B
  o C. Un escenario vago es peor que ninguno: convierte una laguna en un tick
  verde.
- ❌ **No dupliques al `judge` ni al `mutation_tester`.** Tú aportas una sola
  dimensión (seguridad), como `ponytail-review` aporta over-engineering.
  Cobertura general, disciplina TDD y calidad siguen siendo del `judge`.
- ❌ **No escaneas nada que no sea este proyecto.** Los payloads de
  `references/payloads.md` son fixtures para tests **contra el código local**.
  Nada de nmap/ZAP/fuzzing contra hosts, ni siquiera de staging, sin que el
  humano lo pida explícitamente y confirme que es su infraestructura.
- ❌ **No pegues secretos reales en ningún artefacto** (`.feature`,
  `project-spec.md`, `progress/`). Placeholders siempre.
- ✅ **`ponytail` no borra un control de seguridad.** Su propia sección
  *"When NOT to be lazy"* excluye validación en fronteras de confianza y
  medidas de seguridad. Un `@sec` aprobado **no** es candidato a `delete:` en
  `ponytail-review`.
- ✅ **Presupuesto antes que exhaustividad.** 3 escenarios que muerden valen
  más que 20 que nadie mantiene. La guía completa se revisa trimestralmente
  a nivel equipo; aquí solo entra lo que esta feature expone.

---

## Cobertura honesta

Qué porcentaje de la guía del equipo llega a estar **realmente verificado**
por el arnés al usar esta skill:

| Cubeta | Cobertura | Verificado por |
|---|---|---|
| **A** — comportamiento (inyección, authz, validación, lógica de negocio, errores, límites) | Alta: llega a test + mutación | `tdd_craftsman` → `judge` → `mutation_tester` |
| **B** — configuración y forma del código (headers, cookies, secretos, deps, contenedor) | Media: detección en el diff, sin garantía de runtime | `judge` (modo `review`) |
| **C** — infraestructura y proceso (WAF, K8s, incidentes, red team, HSM, accesos) | **Nula por diseño** | Fuera del arnés — se nombra, no se finge |

Dicho claro: esta skill no sustituye un SAST/SCA en CI ni un pentest. Lo que
hace es que la parte del riesgo **que nace en el código de la feature** entre
al mismo circuito de rigor que el resto: contrato → rojo → verde → juicio →
mutación.

---

## Referencias

- `references/frontend.md` — XSS, CSP, cookies, postMessage, redirects, DOM clobbering, prototype pollution.
- `references/backend.md` — inyección, authz/IDOR, rate limiting, SSRF, uploads, errores, deserialización, SSTI, XXE, race conditions, ReDoS, lógica de negocio.
- `references/datos.md` — permisos de DB, RLS multi-tenant, PII y masking, exports, notebooks, pipelines ETL.
- `references/supply-chain.md` — dependencias, lockfiles, secretos, CI/CD, contenedores.
- `references/ia.md` — prompt injection, datos sensibles en prompts, validación de output, API keys.
- `references/payloads.md` — corpus de payloads para los `Given`/`When` de los `@sec`.

Fuente: Guía de Buenas Prácticas de Seguridad del equipo (v2.0, 19 secciones),
sobre OWASP Top 10 2021, ASVS 4.0, NIST SP 800-63B, CWE/SANS Top 25 y STRIDE.
