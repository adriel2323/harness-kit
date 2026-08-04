# Verificación — Cómo demostrar que el trabajo funciona

> Regla de oro: **el agente no dice "funciona", lo demuestra**.
> Toda feature termina con evidencia ejecutable, no con afirmaciones.
> Los comandos concretos viven en `harness.config.sh`.

## Niveles de verificación

### Nivel 1 — Tests unitarios (obligatorio)

Toda función pública del código tiene al menos un test que:

1. Cubre el camino feliz.
2. Cubre al menos un camino de error si la función puede fallar.

Comando: `HARNESS_TEST_VERBOSE_CMD` (o `bash tools/run-tests.sh --verbose`).

### Nivel 2 — Test de integración (obligatorio para features de borde de usuario)

Las features que añaden un comando/endpoint/entrada se verifican ejecutando
la interfaz real contra un entorno aislado (un directorio temporal, una base
en memoria, un servidor de prueba), no solo la unidad interna.

_Adapta el ejemplo a tu stack en `docs/conventions.md`._

### Nivel 3 — Smoke test manual (opcional pero recomendado)

Antes de cerrar la sesión, ejecuta un flujo end-to-end contra un entorno
desechable y compruébalo a ojo.

### Nivel 4 — Trazabilidad de escenarios (obligatorio para features `"sdd": true`)

Cada escenario `@s` de `features/<name>.feature` debe poder mapearse a al
menos un test concreto. El `judge` rechaza si falta cobertura. El
`tdd_craftsman` documenta el mapa en `progress/tdd_<name>.md`:

```markdown
## Trazabilidad
- @s1 (origen vacío → 0) → test_count_origen_vacio
- @s2 (varios → 3)       → test_count_varios
- @s3 (no muta el origen) → test_count_no_muta
```

### Nivel 5 — Prueba de mutación (obligatorio para cerrar una feature sdd)

Una suite verde no basta: hay que demostrar que los tests **muerden**. El
`mutation_tester` corre `HARNESS_MUTATION_CMD` y exige el umbral de
`docs/mutation-testing.md`. Todo mutante sobreviviente se mata con un test
nuevo o se justifica como equivalente en `progress/mutation_<name>.md`.

## Anti-patrones (no hacer)

- ❌ "He añadido el comando, debería funcionar." → falta test ejecutable.
- ❌ Test que solo verifica que la función no lanza error. → tiene que
  comprobar el resultado concreto.
- ❌ Mockear el sistema de archivos/red cuando un recurso real aislado es
  viable. → usa un directorio temporal / fixture real.
- ❌ Marcar la feature como `done` sin pasar `./init.sh`.

## Verificación final antes de cerrar

```bash
./init.sh                                 # debe terminar con [OK] Entorno listo
# y la prueba de mutación sobre lo tocado, por encima del umbral:
#   (ver HARNESS_MUTATION_CMD en harness.config.sh)
```

Si `./init.sh` está rojo o sobreviven mutantes sin justificar, **no**
marques nada como `done`. Anota el bloqueo en `progress/current.md` con
estado `blocked` en `feature_list.json`.

## Modelo de 2 gates (desarrollo vs producción)

> Separar el gate de **desarrollo** (rápido, scope de la feat) del gate de
> **producción** (suite completa, una sola vez al cerrar). No reduce
> cobertura: la suite completa sigue corriendo donde importa (cierre).
> Reduce redundancia: hoy corremos toda la suite para validar un cambio en
> un módulo, decenas de veces.

| Gate | Comando | Cuándo | Qué valida |
|------|---------|--------|------------|
| **Desarrollo** | `./init.sh --fast` | Durante TDD (loop) y review del `judge` | Solo el scope de la feat (`HARNESS_FEAT_SCOPE`). Verificación intermedia. **No** habilita declarar `done`. |
| **Producción** | `./init.sh` (sin flag) | Cierre de sesión (`Stop` hook) y antes de `done`/PR | Suite completa (`HARNESS_TEST_CMD`). Único gate que valida integración completa. |

- `HARNESS_FEAT_SCOPE` vacío → **todo** cae a la suite completa (cero
  regresión: si no se pobla el scope, el comportamiento es idéntico al
  anterior). `init.sh --fast` con scope vacío avisa y omite el paso de
  tests (no FAIL).
- Lo puebla el `tdd_craftsman` al empezar la feat (de los test files que
  tocará) y lo vacía al cerrarla. El `mutation_tester` lo consume para
  correr mutación solo contra el scope (80-90% del tiempo de mutación).
- Umbral de mutación sigue 100%. Las Tres Leyes del TDD no se relajan.
- El `craftsman_lead` **no** flipea `done` con `--fast` solo: el gate de
  producción (suite completa verde) es obligatorio.
