# Gherkin — el contrato ejecutable

> "Once the project-spec.md is done, I have it create a set of .feature
> files from the project-spec.md." Los `.feature` son lo que el humano
> aprueba en la puerta, y el mapa que el `tdd_craftsman` recorre.

Los archivos viven en `features/<name>.feature`, donde `<name>` coincide
con el campo `name` de `feature_list.json`.

## Estructura

```gherkin
Feature: <propósito en una frase>
  Como <rol> quiero <capacidad> para <beneficio>.   # contexto opcional

  @s1
  Scenario: <comportamiento observable>
    Given <estado de partida>
    When <acción concreta del usuario>
    Then <resultado medible: salida / error / código de retorno / efecto>

  @s2
  Scenario: <caso límite o error>
    Given ...
    When ...
    Then ...
```

## Reglas duras

- **Un `Scenario` por comportamiento observable**, incluidos los caminos de
  error (id inexistente, flag inválido, entrada vacía). Si el
  `project-spec.md` menciona un caso límite, tiene su escenario.
- **Tags estables** `@s1`, `@s2`, … Son el identificador que el
  `tdd_craftsman` (mapa `@s → test`) y el `judge` (cobertura) citan.
- **Cada `Then` afirma algo medible.** Prohibido "el sistema funciona". Se
  vale: "Then la salida es exactamente `3`", "Then el código de salida es
  distinto de 0", "Then se lanza el error `NotFound`", "Then la respuesta
  HTTP es 404".
- **Un solo `When` por escenario** (la acción bajo prueba). Si necesitas
  dos acciones, probablemente son dos escenarios.
- **Sin detalles de implementación.** El `.feature` describe
  comportamiento, no funciones ni nombres de variables.

## Ejemplo (independiente del lenguaje)

```gherkin
Feature: Contar elementos
  Como usuario quiero saber cuántos elementos tengo para una visión rápida.

  @s1
  Scenario: Origen vacío devuelve 0
    Given un almacén vacío
    When pido el conteo
    Then el resultado es exactamente "0"
    And la operación termina con éxito

  @s2
  Scenario: Varios elementos devuelve el total exacto
    Given un almacén con 3 elementos
    When pido el conteo
    Then el resultado es exactamente "3"

  @s3
  Scenario: contar no modifica el almacén
    Given un almacén con 2 elementos
    When pido el conteo
    Then el almacén queda idéntico que antes
```

## De Gherkin a test

No imponemos un runner BDD (`behave`, `cucumber`, `pytest-bdd`) para no
añadir dependencias. En su lugar, **cada `Scenario` se traduce a un test**
en el framework nativo de tu lenguaje (`unittest`/`pytest`, `jest`/`vitest`,
`go test`, `cargo test`, JUnit…), con un nombre que cita el escenario:

```
@s1 → test_count_origen_vacio
@s2 → test_count_varios
@s3 → test_count_no_muta
```

El `tdd_craftsman` escribe estos tests uno a uno (Rojo→Verde→Refactor) y
deja el mapa en `progress/tdd_<name>.md`. Así el `.feature` sigue siendo la
fuente de verdad legible por el humano, sin pagar el coste de un framework
BDD. (Si tu equipo ya usa un runner BDD, puedes engancharlo: el contrato
sigue siendo el mismo `.feature`.)
