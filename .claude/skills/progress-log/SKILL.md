---
name: progress-log
description: >
  Protocolo de bitácoras del Craftsman Harness. Úsala al abrir o cerrar una
  sesión, o cuando un subagente termina y hay que registrar su artefacto.
  Activa cuando el trabajo dice "actualiza el progreso", "registra el estado",
  "cierra la sesión" o cuando el craftsman_lead consume el contrato de un
  subagente.
---

# Progress Log

> Transversal al flujo de 5 fases. Gobierna **qué se escribe, cuándo y en qué
> archivo** para que el estado viva en disco, no en el contexto. La evidencia
> en `progress/` es lo que hace funcionar la regla anti-teléfono. Rutas
> relativas a la raíz del proyecto (layout consolidado: `harness-kit/progress/`).

## Regla anti-teléfono — contrato de 4 líneas

Cada subagente escribe su artefacto en disco y devuelve **solo** este bloque;
no narra el contenido:

```
status: done | partial | blocked
artifact: progress/<archivo>.md
risks: <qué puede fallar; vacío si ninguno>
next: <qué hace el siguiente paso>
```

El `craftsman_lead` lee el artefacto de disco antes de avanzar. Nunca confíes
en lo narrado; confía en el archivo.

## Archivos de `progress/` — quién escribe, cuándo

| Archivo               | Quién             | Cuándo                               |
|-----------------------|-------------------|--------------------------------------|
| `current.md`          | craftsman_lead    | Abre sesión; actualiza en tiempo real |
| `history.md`          | craftsman_lead    | Cierre de sesión (append del resumen) |
| `tdd_<name>.md`       | tdd_craftsman     | Al completar cada ciclo R→V→R         |
| `judge_<name>.md`     | judge             | Al emitir el veredicto                |
| `mutation_<name>.md`  | mutation_tester   | Al completar la corrida de mutación   |

## Campos mínimos de cada artefacto

**`tdd_<name>.md`:** mapa `@tag → test` + bitácora de ciclos (Rojo / Verde /
Refactor por escenario).

**`judge_<name>.md`:** `status: done | rejected` + veredicto en una línea +
checkpoints fallidos (vacío si none) + acción requerida si rechazó.

**`mutation_<name>.md`:** `score: X% (umbral: Y%)` + `status: done |
below_threshold` + tabla de mutantes sobrevivientes (vacío si none) + tests
a añadir si bajo umbral.

**`current.md`:** encabezado (feature + inicio + agente activo) + `## Plan` +
`## Bitácora` (append mientras se trabaja) + `## Próximo paso` (dónde retomar
si se interrumpe).

## Ciclo de sesión

1. **Apertura:** lee `current.md`. Si tiene trabajo sin cerrar, reanuda desde
   `## Próximo paso`. Si está en blanco, rellena el encabezado.
2. **Durante:** actualiza `## Bitácora` y `## Próximo paso` en tiempo real.
3. **Cierre:** haz append del resumen a `history.md`; luego vacía `current.md`
   dejando solo la plantilla.

## Qué NO hacer

- ❌ Aceptar contenido narrado por el subagente en lugar de una ruta a archivo.
- ❌ Avanzar de fase con `current.md` desactualizado (es el único estado de
  recuperación ante una interrupción).
- ❌ Modificar o borrar entradas de `history.md`: es append-only.
- ❌ Nombrar archivos de progreso con otro esquema (`log_<name>.md`, etc.).
