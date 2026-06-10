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
