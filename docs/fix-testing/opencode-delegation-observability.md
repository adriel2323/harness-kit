# Visibilidad y arranque en frío al delegar fases a opencode Go

> Contexto: con `active_profile: opencode_go` en `model-map.yaml`, fases como
> `mutation_tester` se delegan a `tools/run-opencode.sh` en vez de
> `Agent()`. Esto trajo dos problemas nuevos que no existían delegando a
> Claude, documentados acá junto con su solución.

## Problema 1 — corridas largas son una caja negra

`opencode run --format json` emite NDJSON, pero el evento de una llamada a
`Bash` (p. ej. correr `mutate.py`, que puede tardar 10-90 minutos) **no se
emite hasta que ese `Bash` termina por completo**. El wrapper
(`run-opencode.sh`) vuelca ese stream a un archivo temporal, pero mientras
dura el `Bash` de mutación no hay ninguna línea nueva que leer — parece
colgado aunque esté progresando normalmente. Confirmado empíricamente: se
inspeccionó el descriptor de archivo del proceso `opencode` en vivo
(`/proc/<pid>/fd`) y el archivo de salida no creció durante todo el tiempo
que `mutate.py` estuvo corriendo un lote de tests.

Además, esto es exactamente el mismo tipo de corrida que ya causó dos
incidentes de mutantes pegados (ver `progress/current.md`, sesión
2026-07-02): si hay que matar el proceso a mitad de camino porque "no se
sabe si avanza", el riesgo de dejar el código de producción corrupto es
real y ya se materializó dos veces.

### Solución: `--progress-file` en `tools/mutate.py`

`mutate.py` ahora acepta `--progress-file <ruta>`. Escribe una línea por
mutante **a medida que se evalúa** (abre, escribe, cierra el archivo en
cada mutante — sin buffers), independiente de cómo el proceso que lo llama
(Claude Agent, opencode, una terminal) maneje su propio stdout.

```bash
python3 harness-kit/tools/mutate.py responder/panel.py \
  --progress-file /tmp/.../mutation-live-panel.log
```

Quien orquesta (`craftsman_lead`) puede leer ese archivo en cualquier
momento con `Read` — es solo lectura, no interfiere con la corrida ni
compite por la base de datos de test compartida (a diferencia de correr una
suite de tests en paralelo para "ver si avanza", que sí podría interferir).

Contenido típico:

```
── arrancando mutación de responder/panel.py ──
── Mutando responder/panel.py ─ 62 mutantes válidos (5 descartados por no compilar) ──
   test_cmd: bash harness-kit/tools/pytest-runner.sh -q tests
  [1/62] muerto    responder/panel.py:213  operador  ('==' -> '!=')
  [2/62] muerto    responder/panel.py:232  operador  ('>=' -> '>')
  ...
```

Limitaciones:
- No hay notificación push cuando el archivo cambia — hay que consultarlo
  (`Read`) cuando se quiera un status, no llega solo.
- Solo ayuda para *este* mecanismo de mutación. Si `gherkin_author` o
  `tdd_craftsman` corridos vía opencode se vuelven corridas largas y opacas
  algún día, van a necesitar su propio mecanismo de progreso (no hay uno
  genérico todavía — candidato a evaluar si se vuelve un problema real).

## Problema 2 — el agente delegado gasta la mayor parte del tiempo explorando

En la primera corrida real de `mutation_tester` vía opencode, de ~35 min
totales, ~33 min fueron lectura/exploración (leer `.claude/agents/
mutation_tester.md`, leer `panel.py`/`main.py` completos, mirar reportes de
mutación anteriores "para el estilo", decidir qué comando de test usar) y
solo ~2 min fueron la mutación real. El modelo del tier `cheap`
(`deepseek-v4-flash`) no tiene el mismo "sentido común de proyecto" que un
subagente Claude — hay que dárselo explícito en el prompt en vez de
esperar que lo redescubra.

### Solución: prompts "en frío cero" — todo resuelto de antemano

Principio para cualquier prompt que se delegue a opencode Go (no solo
`mutation_tester`): el `craftsman_lead` hace el trabajo de investigación
**antes** de lanzar, y el prompt le da al agente delegado:

1. **El contrato de salida citado textual** (las 4 líneas), no "leé
   `.claude/agents/X.md`". Ahorra una lectura de archivo completa.
2. **El/los comando(s) exacto(s) a correr**, ya con todos los flags
   resueltos (rutas, `--max`, `--test-cmd`, `--progress-file`) — no "corré
   la mutación con el comando que corresponda". El `craftsman_lead` ya sabe
   cuál es (puede probarlo él mismo en seco, como se hizo acá contando
   mutantes candidatos con `generate_mutants()` antes de lanzar).
3. **La plantilla del reporte final ya dada** (estructura de encabezados),
   no "mirá los reportes anteriores para el estilo".
4. **Los hallazgos previos relevantes ya resumidos en texto** (p. ej. los
   puntos débiles que señaló `judge`), no "leé el veredicto del judge".
5. **Confirmación explícita de que el baseline ya está verde** (con el
   número exacto de tests), para que no lo re-verifique por las dudas.

Esto no elimina toda exploración (el agente igual puede necesitar mirar el
código fuente para entender qué está mutando), pero saca del camino todo lo
que el orquestador ya sabe y puede simplemente decirle.

### Ejemplo aplicado (feature #3, segundo relanzamiento)

Antes de lanzar, el `craftsman_lead`:
- Contó los mutantes candidatos reales sin correr la suite (importando
  `generate_mutants`/`compiles` de `mutate.py` directamente): 62 válidos en
  `panel.py`, 46 en `main.py`.
- Resolvió el comando canónico (`tools/run-mutation.sh`, que ya carga
  `HARNESS_TEST_CMD` desde `harness.config.sh` — el mismo patrón que usaron
  los reportes de mutación de #1/#2, no el comando ad-hoc con un subconjunto
  de archivos que había improvisado la corrida anterior).
- Preparó dos rutas de `--progress-file` (una por archivo) en el
  scratchpad de la sesión.

**Estado: prompt redactado, NO lanzado todavía** (el humano pidió cancelar
el relanzamiento y solo dejar esto documentado). Queda listo para usarse la
próxima vez que se dispare `mutation_tester` de la feature #3 vía
`tools/run-opencode.sh`. Texto completo del prompt, para copiar/pegar tal
cual (ajustar solo si cambian las rutas de `--progress-file` o el número de
mutantes contados si el código se modifica antes de lanzar):

```text
Actuás como el subagente "mutation_tester" del Craftsman Harness en responder_service. Este prompt ya trae resuelto todo lo que necesitás saber -- no hace falta que leas .claude/agents/mutation_tester.md, ni project-spec.md, ni el veredicto de judge, ni reportes de mutación anteriores. Andá directo a ejecutar los comandos de abajo.

CONTEXTO (ya resuelto, no lo repreguntes):
- Feature #3 panel_historial_kpis, ya aprobada por judge (status: done).
- Baseline confirmado verde AHORA MISMO por el craftsman_lead: "bash harness-kit/init.sh" -> 125 passed. No hace falta que lo vuelvas a correr antes de empezar.
- Alcance de esta mutación: responder/panel.py (62 mutantes válidos, ya contados) y responder/main.py (46 mutantes válidos, ya contados) -- contados de antemano con generate_mutants()/compiles() de mutate.py, sin correr la suite.
- Comando canónico del proyecto para mutación (el mismo que usaron los reportes de las features #1 y #2, YA carga HARNESS_TEST_CMD desde harness.config.sh -- no inventes un test-cmd distinto ni acotes a un subconjunto de archivos):

  cd /home/adriel2323/munisn/salud/auditoria_vacunacion/responder_service
  bash harness-kit/tools/run-mutation.sh responder/panel.py --progress-file <RUTA_SCRATCHPAD>/mutation-live-panel.log
  bash harness-kit/tools/run-mutation.sh responder/main.py --progress-file <RUTA_SCRATCHPAD>/mutation-live-main.log

  (No pases --max: el default de 100 ya cubre los 62/46 mutantes válidos de cada archivo, no hace falta truncar.)

- responder/main.py tiene rutas de OTRAS features (#1, #2, #6) además de las 3 nuevas de #3. Esto es esperado y normal (mismo patrón que el reporte de mutación de #2): mutá el archivo COMPLETO como siempre hace mutate.py, pero en tu reporte final atribuí cada mutante sobreviviente/muerto a la feature que le corresponde por rango de línea:
    * responder/main.py líneas de las 3 rutas nuevas (GET /api/panel/kpis, GET /panel/campanias, GET /panel/campanias/{campaign_id}) -> feature #3, SON tu foco real.
    * cualquier otra línea de main.py -> ya fue mutada y aprobada en reportes anteriores (harness-kit/progress/mutation_panel_backend_datos.md y mutation_panel_resumen_heatmap.md) o es código heredado pre-arnés -- fuera de tu alcance, no la reportes como hallazgo nuevo, simplemente notá que no aplica a #3.
  En responder/panel.py, TODO el archivo es de la feature #3 (las funciones de KPIs 1/2/3/4/6/7 y niveles de color son 100% nuevas de esta feature), así que ahí sí todo mutante es tu foco.

- Dos puntos débiles que judge señaló explícitamente -- confirmalos con la corrida real, no asumas el resultado:
  1. _nivel_meta_minima en responder/panel.py: ¿sobrevive un mutante "<" -> "<=" en la frontera valor == meta/2 porque @s7 no ejerce ese valor límite exacto?
  2. responder/main.py: ¿sobrevive un mutante de "usuario incorrecto" en el chequeo de Basic Auth porque @s2 no lo ejerce con ese caso específico?

- Mientras corre, podés (opcional, no obligatorio) leer los archivos de --progress-file de arriba para ver tu propio avance mutante a mutante -- se van escribiendo en vivo, no hace falta esperar a que termine el comando completo.

- Sobre la corrupción de archivos por corte anormal: tools/mutate.py ya tiene un handler de SIGTERM que restaura el archivo automáticamente ante un kill "amable" (no cubre SIGKILL). Si por cualquier motivo tu corrida se corta a medias, tu ÚLTIMA acción antes de escribir el reporte final tiene que ser correr "bash harness-kit/init.sh" y confirmar 125 passed -- si no, restaurá vos mismo responder/panel.py y/o responder/main.py al estado en que los leíste al principio (esto es limpiar tu propia herramienta, no diseñar código nuevo, así que está permitido aunque tu regla general sea no tocar código de producción).

ESCRIBÍ el reporte completo en harness-kit/progress/mutation_panel_historial_kpis.md con esta estructura exacta (mismo estilo que los reportes anteriores del proyecto):

# Mutación — feature #3 `panel_historial_kpis`

**Veredicto:** PASS | FAIL
**Score (líneas nuevas/tocadas por #3):** <killed>/<total> = **<pct>%** (umbral: 100%)

## Alcance
<qué se mutó, qué líneas de main.py son de #3 vs de otras features/heredadas, igual que se explicó arriba>

## Ejecución
```
bash harness-kit/tools/run-mutation.sh responder/panel.py
bash harness-kit/tools/run-mutation.sh responder/main.py
```

## Resultado detallado
<tabla o lista de mutantes sobrevivientes con archivo:línea, mutación, y por qué sobrevive o qué test lo mata>

## Los dos puntos de judge
<qué encontraste para cada uno de los dos puntos débiles de arriba>

## Conclusión
<PASS/FAIL y next steps si algo sobrevive>

Al final de tu respuesta en el chat (no en el archivo), poné ÚNICAMENTE este bloque de 4 líneas, nada más:
status: done | blocked | partial
artifact: harness-kit/progress/mutation_panel_historial_kpis.md
risks: <una línea, o "-">
next: <recomendación para el craftsman_lead, o "-">
```

**Cómo lanzarlo cuando se decida retomar** (no ejecutado en esta sesión):

```bash
cd harness-kit
bash tools/run-opencode.sh mutation_tester <archivo_con_el_prompt_de_arriba>
```

Reemplazando `<RUTA_SCRATCHPAD>` por una ruta real de scratchpad antes de
guardar el prompt en un archivo.

El prompt resultante no le pide al agente que lea ningún archivo de
protocolo ni que decida el comando: se lo da todo armado, y su trabajo se
reduce a ejecutar, observar los resultados, y escribir el reporte con la
plantilla ya provista.

## Riesgo que sigue abierto

- `SIGKILL` sigue sin poder atraparse (limitación del SO): si el proceso
  muere así, un mutante puede quedar pegado igual. La mitigación de
  `SIGTERM` (`progress/current.md`, "Segundo incidente...") cubre el caso
  de un kill "amable"; no es una garantía absoluta.
- Antes de asumir que el código está roto tras cualquier corte anormal de
  `mutation_tester` (stall, error de conexión, cancelación manual), correr
  `bash harness-kit/init.sh` primero — si falla con una falla puntual y
  aislada (no una cascada), sospechar de un mutante pegado antes que de un
  bug real.

---

## Estado de implementación

> **IMPLEMENTADO (2026-07-02)** — ver `plan-implementacion-fixes.md`.
>
> - **Problema 1** (`--progress-file` + SIGTERM): portado al kit desde el
>   downstream de `responder_service` (que ya lo tenía probado en producción).
>   `tools/mutate.py` ahora acepta `--progress-file` y atrapa SIGTERM vía
>   `signal.default_int_handler` (el `try/finally` restaura el archivo).
> - **Problema 2** (prompts "en frío cero"): documentado como convención
>   obligatoria en `.claude/agents/craftsman_lead.md` (subsección "Prompt en
>   frío cero", bajo "Resolución de modelo"). Sin código: es disciplina del
>   orquestador al redactar el prompt-file.
> - **Riesgo abierto** (SIGKILL): sigue abierto por limitación del SO; la
>   mitigación de SIGTERM cubre el kill amable. Documentado en
>   `docs/verification.md` y en los `mutation_tester.md` de ambos perfiles.
