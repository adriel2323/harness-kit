# Perfil: Rust (cargo). Copiado a harness.config.sh por el instalador.
HARNESS_LANGUAGE="rust"
HARNESS_SRC_DIR="src"
HARNESS_TESTS_DIR="tests"
HARNESS_TEST_CMD="cargo test --quiet"
HARNESS_TEST_VERBOSE_CMD="cargo test"
# En Rust el test único no mapea 1:1 a un archivo (tests en módulos #[cfg(test)]
# o en tests/). Por defecto cae a la suite completa, que es barata por el caché
# de compilación incremental. Para tests de integración: 'cargo test --test {name}'.
HARNESS_TEST_ONE_CMD=""
HARNESS_TEST_FILE_PATTERNS=""
HARNESS_MUTATION_CMD="cargo mutants"
HARNESS_MUTATION_THRESHOLD="100"
HARNESS_BUILD_CMD="cargo build"
HARNESS_LINT_CMD="cargo clippy -- -D warnings"
HARNESS_RUNTIME_CHECK="cargo --version"
# cargo-mutants se instala con: cargo install cargo-mutants
