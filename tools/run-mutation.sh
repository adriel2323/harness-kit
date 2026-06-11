#!/usr/bin/env bash
# run-mutation.sh — Wrapper agnóstico para la prueba de mutación.
#
# Corre HARNESS_MUTATION_CMD sobre el/los archivo(s) indicados, desde la RAÍZ
# del proyecto y con el entorno del arnés cargado (HARNESS_KIT_DIR,
# HARNESS_TEST_CMD, etc. exportados), de modo que:
#   - el comando encuentra src/ y tests/ (cwd = raíz del proyecto), y
#   - mutate.py (si se usa) se localiza vía $HARNESS_KIT_DIR y lee HARNESS_TEST_CMD.
#
# Uso:
#   bash tools/run-mutation.sh <archivo> [args...]
#   bash tools/run-mutation.sh src/cli.py --max 80
set -u
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/harness-env.sh" || exit 1

CMD="${HARNESS_MUTATION_CMD:-}"
case "$CMD" in
  TODO*|"") echo "[harness] HARNESS_MUTATION_CMD sin definir en harness.config.sh" >&2; exit 1 ;;
esac

cd "$HARNESS_PROJECT_ROOT_ABS" || exit 1
exec bash -c "$CMD \"\$@\"" _ "$@"
