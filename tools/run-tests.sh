#!/usr/bin/env bash
# run-tests.sh — Wrapper agnóstico: corre el comando de tests configurado.
#
# Sirve para que los hooks de .claude/settings.json no hardcodeen el lenguaje.
# Pasa --verbose para usar HARNESS_TEST_VERBOSE_CMD.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 1

if [ ! -f "harness.config.sh" ]; then
  echo "[harness] Falta harness.config.sh — corre install.sh" >&2
  exit 1
fi
# shellcheck source=/dev/null
. ./harness.config.sh

CMD="${HARNESS_TEST_CMD:-}"
if [ "${1:-}" = "--verbose" ]; then
  CMD="${HARNESS_TEST_VERBOSE_CMD:-$HARNESS_TEST_CMD}"
fi

case "$CMD" in
  TODO*|"") echo "[harness] HARNESS_TEST_CMD sin definir" >&2; exit 1 ;;
esac

exec bash -c "$CMD"
