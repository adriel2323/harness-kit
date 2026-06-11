#!/usr/bin/env bash
# run-tests.sh — Wrapper agnóstico: corre el comando de tests configurado.
#
# Sirve para que los hooks de .claude/settings.json no hardcodeen el lenguaje.
#   --verbose        usa HARNESS_TEST_VERBOSE_CMD (suite completa, verbosa).
#   --one <file>     corre SOLO el test <file> con HARNESS_TEST_ONE_CMD.
#                    Si esa variable está sin definir, cae a la suite completa.
# Sin flags: corre la suite completa (HARNESS_TEST_CMD).
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

case "${1:-}" in
  --verbose)
    CMD="${HARNESS_TEST_VERBOSE_CMD:-$HARNESS_TEST_CMD}"
    ;;
  --one)
    FILE="${2:-}"
    ONE="${HARNESS_TEST_ONE_CMD:-}"
    case "$ONE" in
      TODO*|"")
        # Sin comando de test único: cae a la suite completa (seguro).
        ;;
      *)
        if [ -n "$FILE" ]; then
          # Sustituye el placeholder {file} por la ruta del test.
          CMD="${ONE//\{file\}/$FILE}"
        fi
        ;;
    esac
    ;;
esac

case "$CMD" in
  TODO*|"") echo "[harness] HARNESS_TEST_CMD sin definir" >&2; exit 1 ;;
esac

exec bash -c "$CMD"
