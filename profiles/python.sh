# Perfil: Python (stdlib unittest). Copiado a harness.config.sh por el instalador.
HARNESS_LANGUAGE="python"
HARNESS_SRC_DIR="src"
HARNESS_TESTS_DIR="tests"
HARNESS_TEST_CMD="python3 -m unittest discover -s tests -q"
HARNESS_TEST_VERBOSE_CMD="python3 -m unittest discover -s tests -v"
HARNESS_MUTATION_CMD="python3 tools/mutate.py"
HARNESS_MUTATION_THRESHOLD="100"
HARNESS_BUILD_CMD=""
HARNESS_LINT_CMD=""
HARNESS_RUNTIME_CHECK="python3 --version"
# Alternativas comunes (descomenta/edita):
#   pytest:   HARNESS_TEST_CMD="python3 -m pytest -q"
#   mutmut:   HARNESS_MUTATION_CMD="mutmut run"
