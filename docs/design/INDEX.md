# Índice de decisiones de diseño (DDR)

> Un DDR (*Design Decision Record*) congela una decisión estructural: el límite
> de un módulo, su interfaz pública y qué esconde. Plantilla en
> `docs/design/PLANTILLA-DDR.md`. Método en la skill `aposd-design`.
>
> **Esta tabla es la que evita abrir la puerta dos veces por la misma decisión.**
> Antes de diseñar nada, se busca acá si el módulo ya tiene una decisión tomada.
> Si la tiene, se cita y se sigue — no se rediscute.

| DDR | Módulo(s) | Decisión (una línea) | Carril | Estado |
|-----|-----------|----------------------|--------|--------|
| _(vacío — todavía no hay decisiones registradas)_ | | | | |

## Cómo se llena

Una fila por DDR, añadida por el `design_partner` al escribirlo y actualizada por
el `craftsman_lead` cuando el humano decide en la puerta.

- **DDR** — enlace: `[DDR-014](DDR-014-normalizacion-padron.md)`
- **Módulo(s)** — las rutas que la decisión gobierna. Es la columna que se busca.
- **Carril** — `trivial` | `estandar` | `estructural`
- **Estado** — `propuesto` | `aprobado por humano` |
  `aprobado por humano (delegado)` | `aplicado por defecto` |
  `reemplazado por DDR-XX`

## Reglas

- **Un DDR es por módulo, no por feature.** Varias features comparten uno. Si
  aparece un DDR por feature, el índice deja de servir para lo que existe.
- **Un DDR entra en una página.** Si no entra, son dos decisiones y hay que
  partirlas.
- **Los descartados se guardan dentro del DDR**, con el porqué. Es lo que evita
  volver a discutir la opción B dentro de un año.
- **`propuesto` bloquea.** Mientras el carril sea estructural y el estado siga en
  `propuesto`, no se despacha ninguna tarea que dependa de esa interfaz.
- **Un DDR no viola `docs/architecture.md`.** El marco (capas, dirección de
  dependencias, contrato de errores) manda; el DDR refina dentro y gana sobre su
  módulo. Violar el marco es un cambio a `architecture.md`, decisión aparte.
