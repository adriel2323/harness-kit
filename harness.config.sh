# harness.config.sh — Config central del arnés (PLANTILLA).
#
# El instalador SOBREESCRIBE este archivo con el perfil del lenguaje detectado
# (ver profiles/). Lo dejamos aquí como referencia del esquema y para que
# init.sh no falle si se ejecuta el kit sin instalar.
#
# Es un archivo de shell que init.sh y los wrappers hacen `source`. NO ejecuta
# nada por sí mismo: solo define variables. Edita una línea para cambiar de
# herramienta (p. ej. unittest → pytest, npm → pnpm).

# Etiqueta del stack. Si vale "TODO" el arnés asume que falta el bootstrap.
HARNESS_LANGUAGE="TODO"

# Directorios. Ajusta a tu layout.
HARNESS_SRC_DIR="src"
HARNESS_TESTS_DIR="tests"

# Ruta (relativa a ESTE archivo) hacia la RAÍZ del proyecto, donde se ejecutan
# los comandos de test/build/mutación (ahí viven src/ y tests/). Vacío o "."
# = aquí mismo (layout plano: el arnés está en la raíz). El instalador la pone
# en ".." cuando el arnés vive en <proyecto>/harness-kit/. Los scripts usan esto
# para distinguir el directorio del arnés (KIT_DIR) de la raíz del proyecto.
HARNESS_PROJECT_ROOT=""

# Comando para correr la suite de tests (silencioso) y su variante verbosa.
# Debe devolver exit code 0 si todo pasa, != 0 si algo falla.
HARNESS_TEST_CMD="TODO: comando de tests"
HARNESS_TEST_VERBOSE_CMD="TODO: comando de tests verboso"

# Comando para correr UN solo test (el del archivo editado) en el loop de TDD.
# `{file}` se reemplaza por la ruta del archivo de test. Si queda vacío o TODO,
# el arnés cae a la suite completa. La suite completa SIEMPRE corre en el gate
# de cierre (Stop → init.sh), así el feedback rápido no sacrifica seguridad.
HARNESS_TEST_ONE_CMD="TODO: comando de un test, p. ej. 'pytest -q {file}'"
# Cómo localizar el archivo de test de un archivo FUENTE editado. Lista de
# plantillas separadas por espacio; `{name}` = basename sin extensión,
# `{dir}` = directorio del fuente. Se corre la primera que exista. Si ninguna
# existe (o el fuente no mapea a un test), el arnés cae a la suite completa.
HARNESS_TEST_FILE_PATTERNS=""

# Comando de mutación. Recibe (opcionalmente) un archivo como argumento.
HARNESS_MUTATION_CMD="TODO: comando de mutación"
HARNESS_MUTATION_THRESHOLD="100"

# --- Scope de la mutacion por git diff (lo aplica run-mutation.sh) -----------
# El umbral se define sobre las lineas NUEVAS O TOCADAS por la feature, no sobre
# el archivo entero. Si tu mutador soporta rangos de linea, declaralos acá y
# run-mutation.sh los saca solo del git diff.
#
#   Stryker (JS/TS):  "{file}:{start}-{end}"
#   mutate.py, PIT, cargo-mutants: no soportan rangos -> dejar VACIO.
HARNESS_MUTATION_RANGE_FMT=""
# Contra que se diffea. HEAD = trabajo sin commitear. Para features que ya
# tienen commits en rama propia, usá la rama de integracion o un merge-base.
HARNESS_MUTATION_DIFF_BASE="${HARNESS_MUTATION_DIFF_BASE:-HEAD}"

# --- Scope de feat (loop rápido + mutación) ---------------------------------
# Lista de test files (separados por espacio) de la feat EN CURSO. Vacío = cae a
# HARNESS_TEST_CMD (suite completa) como hasta hoy. Lo puebla el tdd_craftsman al
# empezar la feat; lo consumen mutate.py (vía run-mutation.sh) e init.sh --fast.
HARNESS_FEAT_SCOPE=""
# Comando que corre SOLO el scope. {scope} se reemplaza por $HARNESS_FEAT_SCOPE.
# Si el scope está vacío, los wrappers caen a HARNESS_TEST_CMD (safe default).
# Ajusta al runner de tu stack (p. ej. 'python3 -m pytest -q {scope}' o
# 'npx vitest run {scope}'); el downstream Python usa tools/pytest-runner.sh.
HARNESS_FEAT_TEST_CMD="bash harness-kit/tools/pytest-runner.sh -q {scope}"
# Comando de tests SOLO para la mutación (lo consume run-mutation.sh). Separado
# de HARNESS_FEAT_TEST_CMD porque el loop rápido de TDD (init.sh --fast) quiere
# ver TODOS los fallos, y la mutación solo mira el returncode por mutante: un
# flag fail-fast (-x en pytest; Stryker/gremlins/PIT traen su propio bail-out)
# es neutro para el veredicto y mucho más rápido en los mutantes muertos.
# {scope} se sustituye por HARNESS_FEAT_SCOPE (si está vacío queda la suite
# completa con fail-fast, que sigue siendo correcto). Vacío = fallback a
# HARNESS_FEAT_TEST_CMD + scope y después a HARNESS_TEST_CMD (comportamiento
# previo, sin fail-fast). Como todo comando del arnés: "plano", shlex-parseable,
# sin operadores de shell. Ej. pytest: "python3 -m pytest -qx {scope}"
HARNESS_MUTATION_TEST_CMD=""

# Opcionales: déjalos vacíos si no aplican.
HARNESS_BUILD_CMD=""
HARNESS_LINT_CMD=""

# Comando barato que prueba que el toolchain está instalado.
HARNESS_RUNTIME_CHECK="true"

# --- Techos de recursos ------------------------------------------------------
# Agregado el 2026-08-21 despues de que un `node --test` huerfano de la mutacion
# creciera a 10.1 GB de RSS, agotara 16 GB de swap y el OOM killer apagara la
# distro WSL completa (systemd tira abajo init.scope entero con OOMPolicy=stop).
#
# HARNESS_MEM_MAX: techo de RAM del comando de tests (lo aplica
# tools/guard-mem.sh via cgroup v2). Sintaxis de systemd: 2G, 512M, 4G...
# "off" desactiva el guard. Si el proceso se pasa, muere SOLO el, con exit 137.
#
# Ojo con la sintaxis "${VAR:-default}": es a proposito y se aparta del resto del
# archivo (asignaciones planas). harness-env.sh hace `set -a` y sourcea este
# config, asi que una asignacion plana PISA lo que venga del entorno. Estos dos
# knobs son justo los que uno quiere subir en una corrida puntual sin editar el
# config ("dale 6G a esta suite pesada"), asi que dejamos ganar al entorno:
#   HARNESS_MEM_MAX=6G bash harness-kit/tools/run-tests.sh
HARNESS_MEM_MAX="${HARNESS_MEM_MAX:-2G}"

# HARNESS_MUTATION_TIMEOUT: segundos que mutate.py le da a la suite por mutante
# antes de darlo por colgado y matar el grupo de procesos entero. Un timeout
# cuenta como mutante MUERTO (la suite no paso) y se marca "muerto(timeout)" en
# el log. Subilo si tu suite es lenta de verdad; no lo pongas en 0.
HARNESS_MUTATION_TIMEOUT="${HARNESS_MUTATION_TIMEOUT:-120}"

