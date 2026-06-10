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

# Comando para correr la suite de tests (silencioso) y su variante verbosa.
# Debe devolver exit code 0 si todo pasa, != 0 si algo falla.
HARNESS_TEST_CMD="TODO: comando de tests"
HARNESS_TEST_VERBOSE_CMD="TODO: comando de tests verboso"

# Comando de mutación. Recibe (opcionalmente) un archivo como argumento.
HARNESS_MUTATION_CMD="TODO: comando de mutación"
HARNESS_MUTATION_THRESHOLD="100"

# Opcionales: déjalos vacíos si no aplican.
HARNESS_BUILD_CMD=""
HARNESS_LINT_CMD=""

# Comando barato que prueba que el toolchain está instalado.
HARNESS_RUNTIME_CHECK="true"
