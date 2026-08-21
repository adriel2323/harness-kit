# Perfil: Node.js / TypeScript (pnpm). Copiado a harness.config.sh por el instalador.
HARNESS_LANGUAGE="node"
HARNESS_SRC_DIR="src"
HARNESS_TESTS_DIR="test"
HARNESS_PROJECT_ROOT=""
HARNESS_TEST_CMD="pnpm test --silent"
HARNESS_TEST_VERBOSE_CMD="pnpm test"
# Un test en el loop. Con vitest: "pnpm dlx vitest run {file}". Con jest:
# "pnpm test -- {file}". Ajusta a tu runner.
HARNESS_TEST_ONE_CMD="pnpm test -- {file}"
HARNESS_TEST_FILE_PATTERNS="{dir}/{name}.test.ts {dir}/{name}.spec.ts test/{name}.test.ts test/{name}.spec.ts {dir}/{name}.test.js"
# Mutacion: Stryker via el wrapper del kit.
#
# CORREGIDO el 2026-08-21. Antes decia `pnpm dlx stryker run`, que no podia
# funcionar con el arnes: run-mutation.sh le pasa el archivo a mutar como
# POSICIONAL, y el unico posicional de Stryker es su archivo de CONFIG. Le
# pasabas src/foo.js y buscaba un config llamado src/foo.js.
#
# stryker-runner.sh traduce esa convencion a `--mutate`, resuelve el binario
# local (sin atarse a npm/pnpm/yarn) y aplica el techo de memoria de
# guard-mem.sh. El resto (runner, timeouts, umbral) va en stryker.config.mjs.
#
# Requiere, en el proyecto:
#   pnpm add -D @stryker-mutator/core @stryker-mutator/tap-runner
# (tap-runner es el que habla con `node --test`; para vitest/jest/mocha usa el
# runner correspondiente y ajusta stryker.config.mjs.)
HARNESS_MUTATION_CMD="bash harness-kit/tools/stryker-runner.sh"
HARNESS_MUTATION_THRESHOLD="100"

# Workers de Stryker en paralelo. Su default es cpuCount-1: en una maquina de 8
# cores son 7 procesos node simultaneos. Ver docs/mutation-testing.md.
HARNESS_MUTATION_CONCURRENCY="${HARNESS_MUTATION_CONCURRENCY:-2}"

# Techo de RAM del arbol ENTERO de Stryker (proceso padre + workers). Separado
# de HARNESS_MEM_MAX, que es para UNA corrida de tests = un solo proceso node.
HARNESS_MUTATION_MEM_MAX="${HARNESS_MUTATION_MEM_MAX:-4G}"

# Scope de la mutacion por git diff (lo aplica run-mutation.sh).
#
# RANGE_FMT declara como escribe rangos de lineas el mutador. Stryker acepta
# "archivo:inicioLinea-finLinea". Vacio = el mutador no soporta rangos y los
# archivos se mutan enteros (es el caso de tools/mutate.py).
HARNESS_MUTATION_RANGE_FMT="{file}:{start}-{end}"

# Contra que se diffea para sacar esas lineas. HEAD = el trabajo sin commitear,
# que es como se desarrollan las features en este repo. Si en tu flujo la feature
# ya tiene commits en una rama propia, poné acá la rama de integracion
# ("origin/main", "origin/develop") o un merge-base.
HARNESS_MUTATION_DIFF_BASE="${HARNESS_MUTATION_DIFF_BASE:-HEAD}"
HARNESS_BUILD_CMD="pnpm run build --if-present"
HARNESS_LINT_CMD="pnpm run lint --if-present"
HARNESS_RUNTIME_CHECK="pnpm --version"
# Alternativas comunes (descomenta/edita):
#   npm:    HARNESS_TEST_CMD="npm test --silent"
#   yarn:   HARNESS_TEST_CMD="yarn test"
#   vitest: HARNESS_TEST_CMD="pnpm dlx vitest run"
