# Perfil: Go. Copiado a harness.config.sh por el instalador.
HARNESS_LANGUAGE="go"
HARNESS_SRC_DIR="."
HARNESS_TESTS_DIR="."
HARNESS_TEST_CMD="go test ./..."
HARNESS_TEST_VERBOSE_CMD="go test -v ./..."
# Un test en el loop: en Go la unidad es el PAQUETE (directorio del archivo).
HARNESS_TEST_ONE_CMD='go test "./$(dirname {file})"'
HARNESS_TEST_FILE_PATTERNS="{dir}/{name}_test.go"
HARNESS_MUTATION_CMD="go-mutesting ./..."
HARNESS_MUTATION_THRESHOLD="100"
HARNESS_BUILD_CMD="go build ./..."
HARNESS_LINT_CMD="go vet ./..."
HARNESS_RUNTIME_CHECK="go version"
# Alternativa de mutación: gremlins (https://github.com/go-gremlins/gremlins)
#   HARNESS_MUTATION_CMD="gremlins unleash"
