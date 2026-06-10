# Arquitectura — Qué significa "hacer un buen trabajo"

> **PLANTILLA.** El agente `harness_bootstrap` (o tú) rellena este documento
> con las reglas reales de tu proyecto. Los agentes revisores evalúan el
> código contra este archivo: **si no está aquí, no es un requisito.**
> Borra los marcadores `TODO:` cuando lo personalices.

## Principios

1. **Capas claras.** _TODO: describe las capas/módulos del proyecto y su
   responsabilidad única. Ejemplo (CLI): `storage` (persistencia), `domain`
   (modelo), `cli` (interfaz). No introducir capas nuevas sin una razón
   documentada en `feature_list.json`._

2. **Dependencias bajo control.** _TODO: ¿stdlib only? ¿qué librerías están
   permitidas? Una dependencia nueva se discute antes (estado `blocked`)._

3. **Errores explícitos.** _TODO: las funciones que pueden fallar lanzan
   errores nombrados / devuelven un Result, no fallan en silencio ni
   devuelven nulo ambiguo._

4. **Inmutabilidad por defecto.** _TODO: ¿estructuras inmutables? Modificar =
   crear una nueva instancia, donde aplique._

5. **Efectos de IO acotados.** _TODO: dónde se permite tocar disco/red/SO, y
   cómo (p. ej. escrituras atómicas: temporal + rename). Mantener la lógica
   de dominio libre de IO._

## Flujo de datos

```
TODO: dibuja el flujo entrada → capas → salida/persistencia de tu proyecto.
```

## Qué NO hacer

- _TODO: anti-patrones concretos de este proyecto._
- No mezclar IO con lógica de dominio.
- No usar el canal de salida estándar para errores (usa el canal de error y
  un código de salida/retorno distinto de éxito).
