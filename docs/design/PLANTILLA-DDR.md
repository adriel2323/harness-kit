# DDR-<id> — <título corto de la decisión>

<!--
Design Decision Record. Guardar en docs/design/DDR-<id>-<slug>.md
Uno por decisión de diseño estructural, POR MÓDULO (no por feature).
Máximo una página: si no entra, la decisión son dos decisiones y hay que partirla.
Al crearlo o cambiarle el estado, actualizar también docs/design/INDEX.md.
-->

| Campo | Valor |
|---|---|
| Fecha | AAAA-MM-DD |
| Carril | trivial / estandar / estructural |
| Estado | propuesto / aprobado por humano / aprobado por humano (delegado) / aplicado por defecto / reemplazado por DDR-XX |
| Spec asociada | <ruta o id> |
| Feature(s) | <ids de feature_list.json que este DDR gobierna> |
| Módulos afectados | <lista de rutas — es lo que se busca en INDEX.md> |

## Problema

<Qué hay que resolver, en términos del dominio. 3–5 líneas. Sin solución acá.>

## Diagnóstico de complejidad

- **Amplificación de cambios:** <cuántos lugares hay que tocar hoy, cuáles>
- **Carga cognitiva:** <qué hay que saber para modificar esto sin romperlo>
- **Incógnitas desconocidas:** <qué no es obvio que hay que mirar>
- **Cambio más caro previsto a 6 meses:** <cuál y cuánto cuesta hoy>

## Opciones consideradas

### A — <nombre>
- Idea:
- Interfaz: `...`
- Oculta:
- Costo hoy / a 6–12 meses:
- Reversibilidad:

### B — <nombre>
<idem>

### C — <nombre> *(opcional)*

## Decisión

**Elegida:** <opción>
**Fundamento:** <atado al diagnóstico, no a preferencia estética>
**Descartadas y por qué:** <una línea por opción — esto es lo que evita volver a discutirlo en 6 meses>
**Esto se revisaría si:** <condición concreta>

## Interfaz congelada

```<lenguaje>
<firma o contrato exacto. Los subagentes de implementación no pueden cambiarlo
sin volver a abrir la puerta.>
```

**Qué oculta este módulo:** <la decisión que queda libre de cambiar sin avisar a nadie>

**Invariantes que la implementación debe preservar:**
- ...

## Deuda declarada

| Deuda | Costo estimado | Disparador para pagarla |
|---|---|---|
| | | |

## Red flags aceptados a conciencia

| Red flag | Por qué se acepta | Cuándo dejaría de aceptarse |
|---|---|---|
| | | |

## Tareas derivadas

- [ ] ...
- [ ] ...

## Supuestos

- <todo lo que se asumió por falta de información; si alguno es falso, el DDR se revisa>
