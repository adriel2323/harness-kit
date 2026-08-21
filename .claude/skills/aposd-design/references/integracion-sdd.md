# Integración con el flujo SDD (orquestador / subagentes)

> **Nota del Craftsman Harness.** Este archivo describe un ciclo spec-kit
> genérico. En este arnés manda la sección «Precedencia del Craftsman Harness»
> de `SKILL.md`. Tres diferencias concretas: (1) el ciclo real es
> spec → gherkin → **diseño** → TDD → judge → mutación; (2) **§4 no aplica** —
> no se emite el bloque YAML `design_gate`, nadie lo parsea; (3) §6 está
> reescrita — `arch-review` no existe acá, las decisiones de infraestructura se
> escalan al humano. Lo que sí sirve tal cual: §2 (contrato de entrada), §3
> (control de coste) y **§5 (el prompt de handoff)**, que es la base del bloque
> de interfaz congelada del `tdd_craftsman`.

Consultá este archivo cuando tengas que **engancharte al ciclo**, **delegar a subagentes**, o **emitir salida legible por máquina**.

---

## 1. Posición en el ciclo

```
constitution → specify → clarify → [ DISEÑO (esta skill) + puerta humana ] → plan → tasks → implement → review
                                              ↑                                              │
                                              └──── vuelve acá si un red flag alto aparece ───┘
```

La fase de diseño es la única del ciclo donde cambiar de idea es gratis. Todo lo que se decide después cuesta código escrito.

### Qué hace en cada fase

**Después de `specify` / `clarify`**
Leé la spec buscando decisiones de diseño encubiertas como requisitos. Señales típicas: la spec nombra tablas, formatos o clases; describe el orden de los pasos internos; o dice "el sistema debe guardar X en Y". Convertilas en preguntas para el diseño en vez de aceptarlas como dadas.

**Fase de diseño (esta skill)**
PASOS 0–8 del SKILL.md. Salida: DDR + interfaz congelada + tareas derivadas.

**En `plan` / `tasks`**
Las tareas se derivan del DDR. Cada tarea de implementación debe traer: el módulo, la interfaz exacta que implementa, los invariantes a preservar, y qué NO tiene que decidir. Una tarea sin interfaz explícita es una invitación a que el subagente invente una.

**En `implement`**
Los subagentes no re-discuten el diseño. Si un subagente encuentra que la interfaz congelada no se puede implementar razonablemente, **eso es un evento de vuelta a la puerta**, no una licencia para improvisar. Debe reportar el bloqueo, no resolverlo por su cuenta.

**En `review`**
Auditá contra dos cosas: (a) el DDR — ¿la implementación respeta la interfaz y los invariantes?; (b) `references/red-flags.md` — ¿aparecieron red flags nuevos durante la implementación? El más frecuente en código generado por agentes es el comentario que repite el código, seguido por módulos someros y sobreexposición de parámetros.

---

## 2. Contrato de entrada

Para producir un diseño útil, necesitás como mínimo:

| Dato | Por qué | Si falta |
|---|---|---|
| La spec o el requerimiento real | Sin el problema no hay diseño | Preguntá; no diseñes contra una suposición |
| Los consumidores previstos de la interfaz | Determina la superficie aceptable | Asumí uno solo y **declaralo como supuesto** |
| Código o estructura existente relevante | Determina qué complejidad ya está pagada | Pedí los archivos concretos, no el repo entero |
| Horizonte: próxima feature conocida del dominio | Es el insumo del "costo a 6–12 meses" | Preguntalo en la puerta; es información que solo tiene el humano |
| Quién mantiene esto después | Cambia el nivel de sofisticación aceptable | Asumí el equipo actual y declaralo |

Los últimos dos son exactamente el tipo de información que justifica abrir la puerta humana.

---

## 3. Control de costo

El análisis de diseño es barato comparado con implementar dos veces, pero no es gratis — y en flujos con subagentes el costo se multiplica.

- **Leé archivos puntuales, no árboles completos.** Pedí las 3–5 rutas que importan.
- **No delegues el diseño a un subagente en paralelo con la implementación.** El diseño es secuencialmente anterior por definición; paralelizarlo produce código escrito contra una interfaz que todavía se está discutiendo.
- **Un subagente por módulo, con la interfaz congelada en su prompt.** Es la forma más efectiva de evitar que cada uno invente su propia abstracción del mismo concepto.
- **El carril trivial existe para no pagar esto.** Si clasificás todo como estructural, la skill se vuelve un impuesto y vas a terminar salteándola.

---

## 4. Bloque `design_gate` (legible por máquina)

Emitilo **solo si el orquestador lo consume**. Si nadie lo parsea, es complejidad autoinfligida y contradice la skill.

```yaml
design_gate:
  ddr_id: DDR-014
  slug: normalizacion-padron
  carril: estructural            # trivial | estandar | estructural
  estado: propuesto              # propuesto | aprobado_humano | aplicado_por_defecto | rechazado
  bloquea_implementacion: true
  opciones:
    - id: A
      nombre: Normalizar en escritura
      interfaz: "PadronRepo.upsert(persona: PersonaNormalizada) -> PersonaId"
      oculta: "formato de origen, reglas de normalización de documento"
      costo_hoy: medio
      costo_6_12m: bajo
      reversibilidad: "requiere migración de datos"
    - id: B
      nombre: Normalizar en lectura
      interfaz: "PadronRepo.get(doc: str) -> PersonaNormalizada"
      oculta: "reglas de normalización"
      costo_hoy: bajo
      costo_6_12m: alto
      reversibilidad: "cambio de código, sin migración"
  recomendacion: A
  fundamento: "El formato de origen ya está parseado en 3 lugares; A lo deja en uno."
  cambiaria_si: "Si entran fuentes nuevas de padrón cada trimestre, gana B."
  supuestos:
    - "Un solo consumidor de la interfaz por ahora"
  interfaz_congelada: null       # se completa al aprobar
  tareas_derivadas: []
```

Reglas: mientras `bloquea_implementacion: true` y `estado: propuesto`, ninguna tarea que dependa de la interfaz puede despacharse. Al aprobarse, `interfaz_congelada` se completa y pasa a ser el contrato que los subagentes reciben literal.

---

## 5. Prompt de handoff a un subagente de implementación

Plantilla para que el orquestador delegue sin perder el diseño:

```
Implementá <módulo> según el DDR-<id> aprobado.

INTERFAZ CONGELADA (no la cambies):
<firma exacta>

QUÉ DEBE OCULTAR ESTE MÓDULO:
<decisión encapsulada>

INVARIANTES A PRESERVAR:
- ...

FUERA DE ALCANCE (no lo decidas vos):
- ...

SI LA INTERFAZ NO SE PUEDE IMPLEMENTAR RAZONABLEMENTE:
No la modifiques. Frená y reportá: qué parte no cierra y qué mínimo cambio la haría viable.

ANTES DE CERRAR, VERIFICÁ:
- Comentario de interfaz escrito, sin detalles de implementación
- Sin comentarios que repitan el código
- Sin parámetros de configuración que no tengan un caso real
- Nombres precisos; ningún `data`, `info`, `manager`, `process`
```

---

## 6. El límite de escala: dónde parás

> **Adaptado al Craftsman Harness.** El original derivaba a una skill hermana
> `arch-review` que **no existe en este árbol**. Acá el destino es el humano.

Hay dos escalas de decisión y esta skill solo cubre una:

| | Escala de sistema | `aposd-design` |
|---|---|---|
| Nivel | Stack, base de datos, despliegue, escalabilidad | Módulo: interfaces, límites, abstracciones |
| Referencia | Kleppmann (DDIA) | Ousterhout (APOSD) |
| Pregunta central | ¿Es proporcional al problema? | ¿Cuánto hay que saber para modificarlo? |
| Momento | Kickoff, evaluación de propuesta | Después de la spec, antes de implementar |
| Quién decide acá | **El humano** | Vos, con puerta si el carril es estructural |

Si durante el diseño aparece una decisión de infraestructura (hace falta una cola, otra base, otro servicio, cambiar el modelo de despliegue), **parás y escalás al humano**: devolvés `status: blocked` nombrando la decisión que te excede. No la resuelvas vos y no la escondas dentro de una opción de diseño.

Al revés también vale: si el humano trae una decisión de infraestructura ya tomada y la conversación baja a "cómo estructuro los módulos adentro", ahí esta skill toma la posta.
