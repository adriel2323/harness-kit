# Perfil: Rust (cargo). Copiado a harness.config.sh por el instalador.
HARNESS_LANGUAGE="rust"
HARNESS_SRC_DIR="src"
HARNESS_TESTS_DIR="tests"
HARNESS_TEST_CMD="cargo test --quiet"
HARNESS_TEST_VERBOSE_CMD="cargo test"
HARNESS_MUTATION_CMD="cargo mutants"
HARNESS_MUTATION_THRESHOLD="100"
HARNESS_BUILD_CMD="cargo build"
HARNESS_LINT_CMD="cargo clippy -- -D warnings"
HARNESS_RUNTIME_CHECK="cargo --version"
# cargo-mutants se instala con: cargo install cargo-mutants
