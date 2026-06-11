# Perfil: Node.js / TypeScript (pnpm). Copiado a harness.config.sh por el instalador.
HARNESS_LANGUAGE="node"
HARNESS_SRC_DIR="src"
HARNESS_TESTS_DIR="test"
HARNESS_TEST_CMD="pnpm test --silent"
HARNESS_TEST_VERBOSE_CMD="pnpm test"
# Un test en el loop. Con vitest: "pnpm dlx vitest run {file}". Con jest:
# "pnpm test -- {file}". Ajusta a tu runner.
HARNESS_TEST_ONE_CMD="pnpm test -- {file}"
HARNESS_TEST_FILE_PATTERNS="{dir}/{name}.test.ts {dir}/{name}.spec.ts test/{name}.test.ts test/{name}.spec.ts {dir}/{name}.test.js"
HARNESS_MUTATION_CMD="pnpm dlx stryker run"
HARNESS_MUTATION_THRESHOLD="100"
HARNESS_BUILD_CMD="pnpm run build --if-present"
HARNESS_LINT_CMD="pnpm run lint --if-present"
HARNESS_RUNTIME_CHECK="pnpm --version"
# Alternativas comunes (descomenta/edita):
#   npm:    HARNESS_TEST_CMD="npm test --silent"
#   yarn:   HARNESS_TEST_CMD="yarn test"
#   vitest: HARNESS_TEST_CMD="pnpm dlx vitest run"
