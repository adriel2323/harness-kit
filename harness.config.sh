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

# Opcionales: déjalos vacíos si no aplican.
HARNESS_BUILD_CMD=""
HARNESS_LINT_CMD=""

# Comando barato que prueba que el toolchain está instalado.
HARNESS_RUNTIME_CHECK="true"
