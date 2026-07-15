#!/usr/bin/env bash
# test-map.sh — Mapa declarado módulo→tests vía cabecera `covers:`.
#
# Dado un archivo FUENTE (ruta relativa a la raíz del proyecto), busca en el
# directorio de tests los archivos cuyas primeras ~15 líneas declaren una
# cabecera `covers:` que incluya esa ruta fuente. Imprime los test files que
# matchean en UNA sola línea, separados por espacio (formato listo para
# sustituir en {scope}/{file}). Sin matches: no imprime nada y sale 0.
#
# La cabecera es AGNÓSTICA al lenguaje: `# covers: ...`, `// covers: ...`,
# `-- covers: ...`; por eso greppeamos `covers:` sin atarnos al líder de
# comentario. El match de la RUTA es de string fijo (grep -F): las rutas llevan
# `/` y no queremos que se interpreten como regex.
#
# Uso:
#   bash tools/test-map.sh <ruta-fuente-relativa> [--tests-dir <dir>]
#
# --tests-dir permite apuntar a otro directorio (debug y fixtures de test);
# por defecto usa HARNESS_TESTS_DIR (única variable de config que necesita).
set -u
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/harness-env.sh" || exit 1

SRC="${1:-}"
[ -n "$SRC" ] || { echo "[harness] test-map.sh: falta la ruta fuente" >&2; exit 1; }
shift

TESTS_DIR="${HARNESS_TESTS_DIR:-tests}"
if [ "${1:-}" = "--tests-dir" ]; then
  TESTS_DIR="${2:-}"
  [ -n "$TESTS_DIR" ] || { echo "[harness] test-map.sh: --tests-dir sin valor" >&2; exit 1; }
fi

cd "$HARNESS_PROJECT_ROOT_ABS" || exit 1

# Sin directorio de tests, no hay mapa: silencio, exit 0 (safe default).
[ -d "$TESTS_DIR" ] || exit 0

# Recolectar los test files cuya cabecera (primeras 15 líneas) tenga una línea
# con `covers:` que incluya la ruta fuente. Encadenamos dos greps: el primero
# acota a las líneas `covers:`, el segundo exige la ruta como string fijo (-F).
matches=""
while IFS= read -r f; do
  if head -n 15 "$f" | grep 'covers:' | grep -qF "$SRC"; then
    matches="${matches:+$matches }$f"
  fi
done < <(find "$TESTS_DIR" -type f | sort)

[ -n "$matches" ] && printf '%s\n' "$matches"
exit 0
