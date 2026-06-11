#!/usr/bin/env bash
# run-tests.sh — Wrapper agnóstico: corre el comando de tests configurado.
#
# Sirve para que los hooks de .claude/settings.json no hardcodeen el lenguaje.
#   --verbose        usa HARNESS_TEST_VERBOSE_CMD (suite completa, verbosa).
#   --one <file>     corre SOLO el test <file> con HARNESS_TEST_ONE_CMD.
#                    Si esa variable está sin definir, cae a la suite completa.
# Sin flags: corre la suite completa (HARNESS_TEST_CMD).
#
# Los comandos se ejecutan en la RAÍZ del proyecto (HARNESS_PROJECT_ROOT_ABS),
# que puede diferir del dir del arnés cuando este vive en harness-kit/.
set -u
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/harness-env.sh" || exit 1

CMD="${HARNESS_TEST_CMD:-}"

case "${1:-}" in
  --verbose)
    CMD="${HARNESS_TEST_VERBOSE_CMD:-$HARNESS_TEST_CMD}"
    ;;
  --one)
    FILE="${2:-}"
    ONE="${HARNESS_TEST_ONE_CMD:-}"
    case "$ONE" in
      TODO*|"") : ;;                       # sin test único: cae a la suite (seguro)
      *) [ -n "$FILE" ] && CMD="${ONE//\{file\}/$FILE}" ;;
    esac
    ;;
esac

case "$CMD" in
  TODO*|"") echo "[harness] HARNESS_TEST_CMD sin definir" >&2; exit 1 ;;
esac

cd "$HARNESS_PROJECT_ROOT_ABS" || exit 1
exec bash -c "$CMD"
