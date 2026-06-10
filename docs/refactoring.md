# Refactoring con el flujo completo — SOLID, desacoplar, reestructurar

> Un refactor **rompe el supuesto base del flujo**: las features añaden
> comportamiento; un refactor cambia la **estructura** sin cambiar el
> **comportamiento observable**. El pipeline sirve entero, pero el contrato
> Gherkin cambia de rol: de "lo que vamos a construir" a **la red de
> seguridad que pinta lo que NO debe cambiar**.

## El cambio de rol de cada artefacto

| | Feature normal | Refactor |
|---|---|---|
| Objetivo | Añadir comportamiento | Cambiar estructura, **mismo** comportamiento |
| El `.feature` | "Lo que vamos a construir" | **Red de seguridad**: "lo que NO debe cambiar" (caracterización) |
| La puerta humana aprueba | El comportamiento nuevo | Que esos escenarios capturan bien el comportamiento actual |
| TDD | Rojo → Verde → Refactor | **Quedarse en verde** mientras reestructuras |
| El `judge` mira | Cobertura de lo nuevo + calidad | Comportamiento intacto **+ que el objetivo SOLID se cumplió** |
| La mutación | Demuestra que los tests muerden | Demuestra que **la red de seguridad es real** (clave aquí) |

## Las dos reglas duras del refactor

1. **Nunca mezcles refactor y cambio de comportamiento** en la misma feature
   ni en el mismo commit. Una entrada de `feature_list.json` = un movimiento
   estructural con el comportamiento congelado. Comportamiento nuevo = otra
   entrada distinta. Si durante el refactor descubres una mejora de
   comportamiento, anótala como feature aparte; no la cueles aquí.
2. **Sin caracterización no hay refactor.** Si el código que vas a mover no
   está cubierto por tests, el primer trabajo es **pintarlo con tests verdes**
   que capturen su comportamiento actual. Solo entonces puedes reestructurar
   con seguridad.

## Cómo arrancar, fase por fase

### 0. Divide por seam (costura)
No metas "aplicar SOLID a todo el módulo" en una sola feature. Pártelo en
movimientos arquitectónicos pequeños, **uno por entrada** en
`feature_list.json`:
- "extraer la persistencia detrás de una interfaz (DIP)"
- "separar validación de notificación (SRP)"
- "introducir un puerto para el reloj/IO (testabilidad)"

Cada uno preserva comportamiento y se cierra por separado.

### 1. Spec (`spec_partner`) — registro de decisión de refactor
La conversación no es "qué hace de nuevo" sino la **decisión de diseño**:
- ¿Qué principio se viola hoy y dónde duele (rigidez, fragilidad, acoplamiento)?
- ¿Cuál es la estructura objetivo y qué seams introduces?
- Alternativas descartadas y por qué.
- Invariante explícita: **"sin cambios de comportamiento observable"**.

Queda en `project-spec.md` como un registro de decisión (dolor → objetivo →
decisiones).

### 2. Gherkin (`gherkin_author`) — caracterización
El `.feature` pinta el **comportamiento ACTUAL** del código que vas a mover:
entradas, salidas, errores, efectos. No describe uno nuevo. Si el legacy no
tiene tests, esto es lo más importante del refactor. La puerta humana es:
*"sí, este es el comportamiento que hay que preservar"*.

> Sugerencia: marca estos escenarios como caracterización, p. ej. un
> `@characterization` además del `@s1`, para que el `judge` sepa que su
> criterio es "siguen verdes", no "cubren algo nuevo".

### 3. TDD (`tdd_craftsman`) — con una adaptación
Dos sub-pasos por cada movimiento:
- **Caracterizar primero:** escribe los tests que codifican los `@s` y que
  **pasan contra el código actual** (la red de seguridad, antes de tocar nada).
- **Refactor en verde:** reestructura en pasos pequeños (extraer clase,
  introducir interfaz, invertir dependencia, inyectar dependencia…), corriendo
  los tests **después de cada movimiento**.

La **Ley 1** ("nada de producción sin un test rojo que la pida") se relaja para
*refactor puro*: no añades comportamiento, así que el listón pasa a ser
**"los tests siguen verdes y el comportamiento no cambió"**. Lo que NO se
relaja: si aparece comportamiento nuevo, paras y lo registras como otra
feature.

### 4. Review (`judge`)
Verifica tres cosas:
- (a) **Comportamiento intacto**: todos los escenarios de caracterización
  siguen cubiertos y verdes.
- (b) **El objetivo se cumplió**: el principio SOLID / el desacople pretendido
  está realmente en el código (cita las decisiones del `project-spec.md`).
- (c) **Sin scope creep**: ningún comportamiento nuevo colado en el refactor.

### 5. Mutación (`mutation_tester`)
Más valiosa que nunca: un refactor "protegido" por tests que no afirman nada
**no está protegido**. La mutación prueba que la red muerde. Si sobreviven
mutantes sobre las líneas movidas, tu seguridad para refactorizar era ilusoria
→ vuelve al `tdd_craftsman` a reforzar la caracterización.

## Plantilla de entrada en `feature_list.json`

Usa el prefijo `[REFACTOR]` en el título para que los agentes apliquen esta
adaptación, y mantén `"sdd": true` (pasa por la puerta humana).

```json
{
  "id": 14,
  "name": "refactor_order_service_dip",
  "title": "[REFACTOR] Invertir dependencia de persistencia en OrderService (DIP)",
  "description": "OrderService instancia SqlOrderRepo directamente. Extraer una interfaz OrderRepository e inyectarla. SIN cambios de comportamiento observable.",
  "acceptance": [
    "Caracterización: el comportamiento actual (crear, validar, error si id duplicado) queda cubierto por tests que pasan ANTES de tocar nada",
    "OrderService depende de la abstracción OrderRepository, no de SqlOrderRepo",
    "La implementación concreta se inyecta desde fuera (constructor)",
    "Todos los escenarios de caracterización siguen verdes tras el refactor",
    "Mutación 100% sobre las líneas tocadas (la red muerde)"
  ],
  "sdd": true,
  "status": "pending"
}
```

Arrancas igual que siempre, en Claude Code:

> «implementa la siguiente feature pendiente»

El `craftsman_lead` lo lleva por el pipeline; apruebas la caracterización en
la puerta humana **antes** de que se mueva una sola clase.

## Anti-patrones

- ❌ Refactor sin caracterización previa ("lo arreglo y luego veo si rompí algo").
- ❌ Meter una mejora de comportamiento "ya que estoy" dentro del refactor.
- ❌ "Big bang": reescribir el módulo entero en una feature. Divide por seam.
- ❌ Declarar el refactor hecho con mutantes vivos sobre las líneas movidas.
