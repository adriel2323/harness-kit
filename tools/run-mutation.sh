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

# Si hay scope de feat, pasarlo como --test-cmd al mutador (mucho más rápido:
# 1 archivo en vez de la suite completa por mutante). Si no, mutate.py lee
# $HARNESS_TEST_CMD como hasta hoy (suite completa = safe default).
SCOPE="${HARNESS_FEAT_SCOPE:-}"
FEAT_TEST_CMD="${HARNESS_FEAT_TEST_CMD:-}"
MUTATION_TEST_CMD="${HARNESS_MUTATION_TEST_CMD:-}"

# Prioridad 1: comando de tests dedicado a la mutación (fail-fast, p.ej. -x de
# pytest). Es neutro para el veredicto (el mutante muere igual con el primer
# fallo) y mucho más rápido en los sobrevivientes. Se sustituye {scope} aunque
# $SCOPE esté vacío: en ese caso queda la suite completa con fail-fast, que
# sigue siendo un fallback seguro (no cambia el comportamiento de hoy salvo
# por el corte anticipado).
if [ -n "$MUTATION_TEST_CMD" ]; then
  RESOLVED="${MUTATION_TEST_CMD//\{scope\}/$SCOPE}"
  exec bash -c "$CMD \"\$@\" --test-cmd \"$RESOLVED\"" _ "$@"
fi

# Prioridad 2 (comportamiento de hoy, sin cambios): si hay scope de feat,
# pasarlo como --test-cmd al mutador. Si no, mutate.py lee $HARNESS_TEST_CMD.
if [ -n "$SCOPE" ] && [ -n "$FEAT_TEST_CMD" ]; then
  RESOLVED="${FEAT_TEST_CMD//\{scope\}/$SCOPE}"
  exec bash -c "$CMD \"\$@\" --test-cmd \"$RESOLVED\"" _ "$@"
fi
exec bash -c "$CMD \"\$@\"" _ "$@"
