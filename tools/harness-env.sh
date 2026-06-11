# harness-env.sh — Resuelve el entorno del arnés. Para SOURCE-arlo (no ejecutar)
# desde init.sh y los wrappers de tools/. Deja definidas y exportadas:
#
#   HARNESS_KIT_DIR          — dir del arnés (config, tools, docs, estado).
#   HARNESS_PROJECT_ROOT_ABS — raíz del proyecto (donde viven src/ y tests/ y se
#                              ejecutan los comandos de test/build/mutación).
#   + todas las variables de harness.config.sh (exportadas con `set -a`).
#
# En layout plano (arnés en la raíz) KIT_DIR == PROJECT_ROOT. Cuando el arnés
# vive en <proyecto>/harness-kit/, HARNESS_PROJECT_ROOT="..", así que
# PROJECT_ROOT_ABS es la raíz del proyecto y KIT_DIR es la subcarpeta.

# tools/.. = raíz del arnés (KIT_DIR), sin importar quién haga el source.
_kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$_kit/harness.config.sh" ]; then
  echo "[harness] Falta harness.config.sh en $_kit — corre install.sh" >&2
  return 1 2>/dev/null || exit 1
fi

set -a
# shellcheck source=/dev/null
. "$_kit/harness.config.sh"
HARNESS_KIT_DIR="$_kit"
HARNESS_PROJECT_ROOT_ABS="$(cd "$_kit/${HARNESS_PROJECT_ROOT:-.}" 2>/dev/null && pwd || echo "$_kit")"
set +a
