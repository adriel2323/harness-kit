# Auditoría de complejidad — mapa de hotspots

> **Plantilla.** Se llena una vez por proyecto, antes de arrancar un ciclo de
> refactor sobre código en producción. Después se actualiza cuando cambia el
> panorama, no en cada feature.
>
> Es el paso que le falta a `docs/refactoring.md`: ese documento explica **cómo**
> llevar un refactor por el pipeline (caracterización → verde → judge → mutación);
> este explica **qué** refactorizar y **en qué orden**.
>
> Método: skill `aposd-design` (`references/red-flags.md`).
> Evidencia barata: `bash tools/complexity-scan.sh`.

## Regla de priorización

Se prioriza por **cuánto cuesta el próximo cambio**, no por cuántos red flags
hay. Un problema grave en un archivo que nadie toca hace tres años no es una
prioridad; uno mediano en el archivo que se toca todas las semanas sí.

```
prioridad ≈ churn × severidad del red flag
```

El churn sale de git. La severidad sale del catálogo:

| Severidad | Red flags | Por qué pesan |
|---|---|---|
| **Alta** | Filtración de información (#2), descomposición temporal (#3), código no obvio (#14) | Producen incógnitas desconocidas y amplificación de cambios |
| **Media** | Módulo somero (#1), sobreexposición (#4), mezcla especial-general (#8), métodos siameses (#9) | Cargan a todos los consumidores, para siempre |
| **Baja** | Pasamanos (#5, #6), repetición (#7), comentarios redundantes (#10, #11), nombres vagos (#12) | Molestos y baratos; se arreglan de paso, no merecen un refactor propio |

**Los de severidad baja no entran en esta tabla.** Se arreglan mientras se pasa
por ahí. Si están acá, la auditoría se volvió una lista de tareas y nadie la va
a mirar.

---

## Cómo se hace

### Paso 1 — Evidencia de git (barato, sin LLM)

```bash
bash tools/complexity-scan.sh                     # todo el historial
bash tools/complexity-scan.sh --since "2 years ago" --top 30
```

Dos salidas:

- **Churn** — cuánto se toca cada archivo. Es el proxy empírico del "próximo
  cambio".
- **Co-cambio** — qué archivos cambian juntos. Un par alto entre archivos que
  **no se importan entre sí** es amplificación de cambios medida: hay una
  decisión de diseño viviendo en dos lugares. Es el mejor candidato a DDR que
  vas a encontrar, y salió gratis.

> Si el reporte avisa de historial importado o aplastado, el churn dice poco.
> Se sigue igual, pero apoyándose en la lectura, no en los números.

### Paso 2 — Barrido de lectura

Sobre los archivos que el paso 1 puso arriba, **no sobre el repo entero**. Se
lanzan 3-5 `Explore` en paralelo, uno por pregunta acotada:

| Pregunta | Red flag | Cómo se detecta |
|---|---|---|
| ¿Qué conocimiento está duplicado? | #2 Filtración | *"si mañana cambio el formato de X, ¿cuántos archivos toco?"* |
| ¿Hay módulos cortados por orden de ejecución? | #3 Descomposición temporal | `leer/validar/transformar/escribir` como piezas separadas que conocen el mismo esquema |
| ¿Qué firmas públicas tienen >4 parámetros o flags booleanos? | #4 Sobreexposición | Lectura de firmas |
| ¿Qué nombres son `data`, `info`, `manager`, `utils`, `process`, `handle`? | #12 Nombre vago | Un `grep` — lo más barato de todo |
| ¿Qué módulos tienen interfaz grande sobre implementación chica? | #1 Somero | Métodos públicos vs. líneas útiles |

Cada hallazgo se escribe con `archivo:línea`. Sin evidencia concreta no es un
hallazgo, es un adjetivo.

### Paso 3 — Llenar la tabla de abajo

### Paso 4 — Puerta humana de priorización

**Se eligen 3 hotspots. No más.** El ranking técnico no reemplaza al roadmap:
qué módulo va a recibir features el próximo trimestre es información que solo
tiene el humano.

### Paso 5 — Un DDR por hotspot elegido

Diseñarlo dos veces sobre la pregunta *"¿dónde debería vivir este
conocimiento?"*. Salida: **interfaz objetivo congelada** y el orden de los
movimientos. Plantilla en `docs/design/PLANTILLA-DDR.md`.

### Paso 6 — Traducir a `feature_list.json`

Cada movimiento hacia la interfaz objetivo es una entrada `[REFACTOR]`
(plantilla en `docs/refactoring.md`). De ahí en adelante manda el pipeline de
siempre.

**El orden importa y es este:**

```
auditoría → DDR (interfaz objetivo) → caracterización ACOTADA AL SEAM
          → mover en verde → judge → mutación
```

El DDR va **antes** de la caracterización: es el que dice qué comportamiento hay
que pintar. Caracterizar antes de saber dónde cae el seam produce tests sobre
código que va a desaparecer.

---

## Mapa de hotspots

<!-- Ordenado por prioridad (churn × severidad). Máximo ~10 filas: si hay más,
     la auditoría dejó de ser un mapa y se volvió un inventario. -->

| # | Hotspot | Churn | Síntoma observado | Evidencia | Red flag | Sev. | Próximo cambio que se vuelve caro |
|---|---------|-------|-------------------|-----------|----------|------|-----------------------------------|
| 1 | | | | `archivo:línea` | #N | Alta | |
| 2 | | | | | | | |
| 3 | | | | | | | |

### Co-cambios sin dependencia declarada

<!-- Pares que cambian juntos pero no se importan entre sí. Cada fila es un
     candidato directo a DDR: hay una decisión que vive en dos lugares. -->

| A ↔ B | Juntos | A→B | ¿Se importan? | Qué conocimiento comparten |
|-------|--------|-----|---------------|----------------------------|
| | | | No | |

---

## El cambio más caro previsto

> *"El cambio más caro que este diseño va a tener que absorber en los próximos
> 6 meses es **\_\_\_**, y hoy cuesta **\_\_\_**."*

Una frase, concreta, con el nombre del requerimiento real — no "si escala". Si
no se puede completar, la auditoría no terminó: falta hablar con quien conoce el
roadmap.

---

## Decisión de la puerta

| Hotspot elegido | Por qué este y no otro | DDR | Entradas `[REFACTOR]` |
|-----------------|------------------------|-----|------------------------|
| | | | |

**Descartados en esta ronda y por qué:**

<!-- Igual de importante que los elegidos: evita volver a discutirlo el mes que
     viene, y deja escrito qué tendría que cambiar para que suban. -->

- …

---

## Anti-patrones de esta auditoría

- ❌ **Rankear por cantidad de red flags.** Un archivo con ocho problemas
  triviales que nadie toca importa menos que uno con un problema grave en el
  camino caliente.
- ❌ **Listar los de severidad baja.** Se arreglan de paso; en la tabla solo
  hacen ruido.
- ❌ **Elegir más de 3 hotspots.** Una lista larga no se ataca, se archiva.
- ❌ **Adjetivos sin `archivo:línea`.** "Está acoplado" no es un hallazgo.
- ❌ **Refactor sin DDR.** Sin interfaz objetivo escrita, el refactor es mover
  código de lugar y esperar que quede mejor.
- ❌ **Confundir co-cambio con acoplamiento necesario.** Un test y su fuente
  cambian juntos y está bien. Lo que interesa son los pares que cambian juntos
  **sin** una razón declarada.
