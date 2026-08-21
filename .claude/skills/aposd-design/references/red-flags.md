# Catálogo de Red Flags (APOSD)

Guía de consulta para los PASOS 2, 3 y 7, y para revisión de PR.
Cada red flag: **síntoma observable → por qué duele → corrección → cuándo NO corregirlo**.

Un red flag no es un error. Es una señal de que ahí hay complejidad que probablemente se puede eliminar. La pregunta correcta nunca es "¿está el red flag?" sino "¿el costo de sacarlo es menor que el costo de convivir con él?".

## Índice

1. [Módulo somero (Shallow Module)](#1-módulo-somero)
2. [Filtración de información (Information Leakage)](#2-filtración-de-información)
3. [Descomposición temporal (Temporal Decomposition)](#3-descomposición-temporal)
4. [Sobreexposición (Overexposure)](#4-sobreexposición)
5. [Método pasamanos (Pass-Through Method)](#5-método-pasamanos)
6. [Variable pasamanos (Pass-Through Variable)](#6-variable-pasamanos)
7. [Repetición (Repetition)](#7-repetición)
8. [Mezcla especial-general (Special-General Mixture)](#8-mezcla-especial-general)
9. [Métodos siameses (Conjoined Methods)](#9-métodos-siameses)
10. [Comentario que repite el código](#10-comentario-que-repite-el-código)
11. [Documentación de implementación en la interfaz](#11-documentación-de-implementación-en-la-interfaz)
12. [Nombre vago / nombre difícil de elegir](#12-nombre-vago--nombre-difícil-de-elegir)
13. [Difícil de describir](#13-difícil-de-describir)
14. [Código no obvio](#14-código-no-obvio)
15. [Severidad y priorización](#severidad-y-priorización)

---

## 1. Módulo somero

**Síntoma:** la interfaz es casi tan complicada como la implementación. Clases de tres líneas útiles con cinco métodos públicos. Wrappers que solo renombran.

**Por qué duele:** cada módulo tiene un costo fijo de existencia (aprenderlo, encontrarlo, mantener su contrato). Un módulo somero cobra ese costo sin devolver casi nada. Muchos módulos someros producen la sensación de "está todo prolijo pero no entiendo nada" (*classitis*).

**Corrección:** juntarlo con su llamador o con su par natural; o profundizarlo absorbiendo responsabilidad que hoy está en los llamadores.

**Cuándo NO:** cuando el módulo somero existe para aislar una dependencia externa que sabés que va a cambiar (adapter contra un proveedor, contra una API de terceros). Ahí la profundidad es futura y vale.

---

## 2. Filtración de información

**Síntoma:** una decisión de diseño aparece reflejada en más de un módulo. Dos clases que conocen el mismo formato de archivo, el mismo esquema JSON, la misma convención de nombres de columna, la misma unidad de medida.

**Por qué duele:** cambiar esa decisión obliga a tocar N lugares — amplificación de cambios pura. Y no hay ninguna referencia cruzada que le avise al próximo que tiene que tocar los dos.

**Cómo detectarla sin ver imports:** buscá conocimiento compartido, no llamadas compartidas. Preguntá: "si mañana cambio el formato de X, ¿cuántos archivos toco?".

**Corrección:** unificar en un módulo, o mover el conocimiento hacia abajo hasta que solo un nivel lo conozca.

**Cuándo NO:** duplicación superficial que solo se parece (dos regex parecidas para dominios distintos). Unificarlas crea el red flag #8.

---

## 3. Descomposición temporal

**Síntoma:** los módulos están cortados por el orden en que ocurren las cosas: `leer → validar → transformar → escribir`, cada uno una clase, cada uno conociendo el mismo formato.

**Por qué duele:** es la fábrica más productiva de filtración de información. El orden de ejecución casi nunca coincide con el reparto correcto de conocimiento.

**Corrección:** cortar por **qué esconde cada pieza**, no por cuándo corre. Si leer y escribir comparten el formato, el formato es un módulo y ambos lo usan.

**Nota para pipelines de datos:** un ETL sí tiene etapas temporales reales. La corrección no es eliminar las etapas, es que las etapas no conozcan el esquema por su cuenta: el esquema vive en un lugar y las etapas lo consumen.

---

## 4. Sobreexposición

**Síntoma:** para usar el caso común hay que aprender features que solo importan en casos raros. Constructores con 9 parámetros. Flags de configuración que existen porque nadie quiso decidir.

**Por qué duele:** carga cognitiva pagada por todos los usuarios para beneficio de unos pocos.

**Corrección:** default sensato + escape hatch aparte. Si un parámetro de configuración no tiene un caso real y documentado que lo justifique, no existe: elegí el valor vos y bajá la complejidad.

---

## 5. Método pasamanos

**Síntoma:** un método que tiene casi la misma firma que el método al que llama y no agrega nada.

**Por qué duele:** aumenta la superficie sin aumentar la funcionalidad, y crea la duda "¿cuál de los dos uso?".

**Corrección:** exponer el de abajo, o darle al de arriba una responsabilidad real (agregar, validar, traducir el modelo).

**Cuándo NO:** si el pasamanos existe para cruzar una frontera de capa donde el tipo cambia (DTO ↔ dominio), no es pasamanos: está traduciendo, que es trabajo real.

---

## 6. Variable pasamanos

**Síntoma:** un parámetro que se arrastra por cinco funciones que no lo usan, solo para llegar a la sexta (típico: `config`, `logger`, `request_id`, `db_session`).

**Por qué duele:** todas las capas intermedias quedan acopladas a algo que no les incumbe.

**Correcciones, en orden de preferencia:** (a) el objeto que ya viaja puede llevarlo; (b) un objeto de contexto explícito compartido; (c) variable de contexto/scope (último recurso, porque es oscuridad).

---

## 7. Repetición

**Síntoma:** el mismo patrón de código aparece una y otra vez.

**Por qué duele:** amplificación de cambios y divergencia silenciosa (uno se arregla, el otro no).

**Corrección:** extraer, o rediseñar para que la repetición deje de ser necesaria. Preferí lo segundo: la mejor deduplicación no es un helper, es un diseño donde el caso no se repite.

**Cuándo NO:** dos cosas que hoy se ven iguales pero cambian por razones distintas. Se van a separar solas, y unirlas ahora es crear un acoplamiento falso.

---

## 8. Mezcla especial-general

**Síntoma:** un mecanismo general contaminado con el caso particular que motivó su creación. Un `if tenant == "municipalidad"` adentro de la librería genérica.

**Por qué duele:** el módulo general deja de ser reusable y el caso especial deja de ser visible.

**Corrección:** el mecanismo general no conoce casos; los casos se resuelven arriba, configurando o componiendo el mecanismo.

---

## 9. Métodos siameses

**Síntoma:** dos piezas separadas que no se pueden entender ni modificar por separado; para leer una tenés que tener la otra abierta al lado.

**Por qué duele:** la separación es aparente. Pagás el costo de dos módulos y obtenés la comprensibilidad de uno mal escrito.

**Corrección:** juntarlas. La pregunta de Ousterhout es literal: *¿mejor juntas o mejor separadas?* — y separar tiene costo, no solo beneficio.

**Cuándo juntar suele ganar:** comparten información, se usan siempre juntas, se superponen conceptualmente, o hay que leer una para entender la otra.

---

## 10. Comentario que repite el código

**Síntoma:** `# incrementa el contador` sobre `contador += 1`. Docstrings generados que parafrasean la firma.

**Por qué duele:** costo de mantenimiento sin información nueva, y entrena al lector a ignorar los comentarios — incluidos los que sí importan.

**Corrección:** el comentario debe aportar **lo que el código no puede decir**: unidad, rango, invariante, por qué, qué pasa si falla, qué NO hace.

**Nota para agentes:** este red flag es el más frecuente en código generado por LLM. Al revisar output de subagentes, buscalo primero.

---

## 11. Documentación de implementación en la interfaz

**Síntoma:** el docstring público explica cómo está hecho por dentro (estructuras, algoritmo, tablas que toca).

**Por qué duele:** el consumidor termina dependiendo de detalles internos y ya no podés cambiarlos.

**Corrección:** dos bloques separados. Interfaz: qué hace, qué recibe, qué garantiza, qué errores. Implementación: adentro, para quien la edita.

---

## 12. Nombre vago / nombre difícil de elegir

**Síntoma:** `data`, `info`, `manager`, `helper`, `process()`, `handle()`, `utils`. O bien: tardaste 5 minutos y no encontraste ninguno bueno.

**Por qué duele:** el nombre es la interfaz más leída de todas. Un nombre vago obliga a leer la implementación cada vez.

**Corrección:** un nombre bueno es preciso y consistente: crea una imagen mental clara y se usa siempre para lo mismo. Si no aparece, el problema es el concepto: probablemente la pieza hace dos cosas o media.

**Uso diagnóstico:** la dificultad para nombrar es una de las señales más baratas y confiables de mal diseño. No la ignores, usala.

---

## 13. Difícil de describir

**Síntoma:** el comentario de interfaz sale largo, con condicionales, o con "excepto cuando".

**Por qué duele:** la complejidad de la descripción es proporcional a la complejidad que el consumidor va a sufrir.

**Corrección:** rediseñar hasta que la descripción sea corta y completa. Escribir el comentario primero convierte esto en una prueba temprana, antes de gastar la implementación.

---

## 14. Código no obvio

**Síntoma:** un lector competente del equipo tarda en entender qué hace o por qué. Comportamiento que sorprende. Efectos laterales que el nombre no anticipa.

**Por qué duele:** es la fuente directa de las incógnitas desconocidas.

**Correcciones:** nombres, comentarios estratégicos, tipos explícitos, evitar side effects escondidos, evitar "inteligencia" innecesaria.

**Cómo medirlo:** la obviedad se juzga desde la cabeza del lector, no del autor. Si un revisor preguntó, no es obvio — aunque tengas razón.

---

## Severidad y priorización

Cuando aparecen varios red flags, priorizá por **cuánto cuesta el próximo cambio**, no por cuántos hay:

| Prioridad | Red flags | Razón |
|---|---|---|
| Alta | Filtración de información, descomposición temporal, código no obvio | Producen incógnitas desconocidas y amplificación de cambios |
| Media | Módulo somero, sobreexposición, mezcla especial-general, métodos siameses | Cargan a todos los consumidores, para siempre |
| Baja | Pasamanos, variables pasamanos, comentarios redundantes, nombres vagos | Molestos y baratos de arreglar; ideales para el 10–20% estratégico de cada tarea |

Regla práctica: **arreglá los de prioridad baja mientras pasás por ahí; los de prioridad alta merecen una decisión de diseño registrada** (y posiblemente una puerta humana).
