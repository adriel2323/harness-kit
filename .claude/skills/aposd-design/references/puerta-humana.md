# Protocolo de la Puerta Humana

Consultá este archivo cuando tengas que decidir **si abrir la puerta**, **cómo escribirla**, o **qué hacer con la respuesta**.

La puerta humana existe por una razón concreta: hay información que el orquestador no tiene y no puede inferir del repo — el roadmap real, quién va a mantener el código, qué prometió alguien en una reunión, qué política interna aplica, cuánta tolerancia hay al riesgo esta semana. La puerta no es un pedido de permiso: es una consulta dirigida a la información que falta.

Si no podés nombrar qué información te falta, probablemente no necesites la puerta. Decidí y registrá.

---

## 1. Criterios de apertura

### Abrir siempre

- **Interfaz pública nueva** que van a consumir otros módulos, equipos o agentes.
- **Cambio de límite entre módulos** o entre servicios (mover responsabilidad de un lado al otro).
- **Esquema de datos persistido**: tablas, migraciones, formato de mensajes, contrato de API.
- **Decisión que un subagente no puede revertir solo** porque ya habrá código escrito contra ella.
- **Trade-off donde el criterio depende del roadmap**: "esto conviene si en 6 meses X". No lo adivines.
- **Cuando las alternativas están genuinamente empatadas** y el desempate es de negocio, no técnico.

### No abrir

- Cambio interno a un módulo, sin efecto en su interfaz.
- Decisión reversible en menos de una hora sin coordinar con nadie.
- Ya existe un DDR aprobado que cubre este caso: citalo y seguí.
- El usuario pidió explícitamente modo rápido / sin puerta.
- La diferencia entre opciones es estética (nombres, estilo, dónde va el archivo).

### Zona gris → abrí

El costo es asimétrico. Una puerta innecesaria cuesta 30 segundos de lectura; una decisión estructural equivocada cuesta días. Ante duda real, abrí — pero achicá el formato: una pregunta, dos opciones, una recomendación.

---

## 2. Cómo construir buenas alternativas

Las opciones tienen que ser **decisiones distintas**, no redacciones distintas.

**Test rápido:** si las tres opciones exponen la misma interfaz pública, no son alternativas de diseño.

Ejes que sí generan alternativas reales:

| Eje | Pregunta | Ejemplo |
|---|---|---|
| Ubicación del límite | ¿Quién se hace cargo de la complejidad? | ¿Valida el llamador o valida el módulo? |
| Momento | ¿Cuándo se paga el trabajo? | Normalizar al escribir vs. al leer |
| Forma del contrato | ¿Datos o comportamiento? | Config declarativa vs. hooks |
| Granularidad | ¿Uno grande o dos chicos? | Un módulo de padrón vs. lector + validador |
| Alcance | ¿Específico o algo general? | Solo este caso vs. mecanismo para la familia de casos |
| **No hacerlo** | ¿Y si resolvemos con lo que ya hay? | Siempre incluila cuando sea plausible |

La opción "no lo hagas / usá lo que ya existe" merece estar presente cada vez que sea plausible. Es la que más veces gana en la práctica y la que menos veces se presenta.

---

## 3. Escribir la recomendación

La recomendación es el corazón de la puerta. Tres reglas:

1. **Fundamento atado al diagnóstico.** "Recomiendo A porque el diagnóstico mostró que el formato del padrón ya está duplicado en 3 lugares y A lo deja en uno" es un fundamento. "A es más limpio" no.
2. **Condición de cambio de opinión.** Escribí literalmente qué tendría que ser verdad para que gane otra. Esto le permite al humano decidir con datos que vos no tenés, sin tener que reconstruir tu razonamiento.
3. **Supuestos explícitos.** Todo lo que asumiste por falta de información va listado. Si un supuesto es falso, el usuario lo ve al toque y corrige sin discutir el resto.

Evitá:
- Recomendar la opción intermedia por default ("la B, que es el equilibrio"). Muchas veces el equilibrio es la peor: paga los costos de las dos puntas.
- Recomendar la más completa por miedo a quedarte corto. La generalidad no pedida es deuda, no seguro.
- No recomendar. Devolverle tres opciones sin postura al usuario es trasladarle el trabajo que la skill vino a hacer.

---

## 4. Qué hacer con la respuesta

| Respuesta | Acción |
|---|---|
| Elige A/B/C | Registrá DDR con estado `aprobado por humano`, congelá la interfaz, derivá tareas |
| Pide una cuarta | Diseñala explorando el eje que su comentario reveló; no repitas las anteriores |
| Responde con información nueva ("en septiembre entra turnos") | Re-evaluá: puede cambiar la recomendación. Decilo explícitamente si cambia |
| Responde parcial ("A pero sin la cache") | Es una opción nueva: reescribí la interfaz resultante antes de implementar |
| No responde y el carril es **estructural** | **No avances.** Dejá el DDR en `propuesto` y trabajá en tareas que no dependan de esta decisión |
| No responde y el carril es **estándar** | Avanzá con la recomendada, estado `aplicado por defecto`, y dejalo visible arriba del DDR |
| "Dale, hacé lo que te parezca" | Es aprobación de la recomendada. Registrá con estado `aprobado por humano (delegado)` |

**Nunca** interpretes silencio como aprobación en carril estructural, aunque haya urgencia. Si hay urgencia real, la salida correcta es proponer la opción más reversible y decir que es provisoria, no elegir la definitiva sin consulta.

---

## 5. Registro de la decisión

Toda puerta cerrada produce un DDR (ver `assets/plantilla-ddr.md`). Guardalo donde el flujo lo pueda leer después — típicamente `docs/design/DDR-<id>-<slug>.md` en el repo del proyecto.

El DDR sirve para tres cosas concretas:
- **Los subagentes de implementación** leen la interfaz congelada y no la re-discuten.
- **La fase de review** compara el código contra la decisión, no contra el gusto del revisor.
- **El vos de dentro de seis meses** entiende por qué esto es así y qué alternativa se descartó y con qué argumento. Esto último es lo que más se pierde y lo que más caro sale.

Guardá siempre **las opciones descartadas y por qué**. Un DDR sin las descartadas es la mitad de un DDR: cuando alguien proponga la opción B dentro de un año, hay que poder responder sin volver a pensarla.

---

## 6. Formato corto (cuando el carril es estándar)

No toda puerta necesita el formato completo. Versión mínima aceptable:

```markdown
## 🚪 Decisión: <pregunta en una línea>

**A —** <idea>. Expone `<firma>`. Barato hoy, pero <costo futuro concreto>.
**B —** <idea>. Expone `<firma>`. Más trabajo hoy, oculta <qué>.

**Recomiendo B.** <2 líneas de fundamento atado al diagnóstico>
**Cambiaría a A si** <condición concreta>.

Respondé A o B; si no, sigo con B y lo dejo asentado.
```

Usá esta versión cuando la decisión es acotada y el usuario está en el celular. La versión larga es para lo estructural.
