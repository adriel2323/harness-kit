#!/usr/bin/env bash
# tools/mirror-check.sh — Detecta drift entre los subagentes Claude y su espejo
# opencode.
#
# El perfil híbrido (`active_profile: opencode_go`) delega fases a
# `.opencode/agents/<X>.md`, que son copias manuales de `.claude/agents/<X>.md`.
# Nada las mantiene sincronizadas: cuando el gemelo Claude gana una sección, el
# espejo se queda atrás **en silencio** y la fase corre con un prompt viejo.
# Precedente real: el espejo perdió la cabecera `covers:` durante meses, y de
# ella dependen tools/test-map.sh, el scope de la mutación y el judge.
#
# Compara SOLO los encabezados `##` — la estructura, no la prosa. Las
# diferencias de redacción entre gemelos son legítimas; una sección entera que
# falta, no. Tampoco compara frontmatter (los formatos son distintos por diseño:
# `tools:` en Claude, `permission:` en opencode).
#
# Salida: warnings. SIEMPRE termina en 0 — esto informa, no bloquea.
#
# Uso: bash tools/mirror-check.sh [--quiet]
#   --quiet: no imprime nada si no hay drift (modo init.sh).

set -u

YELLOW='\033[0;33m'; GREEN='\033[0;32m'; NC='\033[0m'
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCODE_DIR="$KIT_DIR/.opencode/agents"

# Los dos layouts que existen: en el repo del kit, `.claude/` está junto a
# `tools/`; instalado, el arnés vive en <proyecto>/harness-kit/ y `.claude/`
# cuelga de la raíz del proyecto (así lo copia install.sh). El espejo opencode,
# en cambio, siempre está dentro del kit — run-opencode.sh hace cd ahí.
CLAUDE_DIR=""
for cand in "$KIT_DIR/.claude/agents" "$KIT_DIR/../.claude/agents"; do
  if [ -d "$cand" ]; then CLAUDE_DIR="$(cd "$cand" && pwd)"; break; fi
done

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

say_ok()   { [ "$QUIET" -eq 1 ] || printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
say_warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }

if [ ! -d "$OPENCODE_DIR" ]; then
  say_ok "sin espejo opencode (.opencode/agents/): nada que comparar"
  exit 0
fi

if [ -z "$CLAUDE_DIR" ]; then
  say_warn "no encontré .claude/agents/ (ni en el kit ni en la raíz del proyecto): comparación omitida"
  exit 0
fi

# Encabezados `##` (cualquier nivel >= 2), sin el prefijo de almohadillas.
headings() { grep -E '^#{2,} ' "$1" 2>/dev/null | sed -E 's/^#+ +//; s/[[:space:]]+$//'; }

drift=0
pairs=0

for mirror in "$OPENCODE_DIR"/*.md; do
  [ -e "$mirror" ] || continue
  name="$(basename "$mirror")"
  origin="$CLAUDE_DIR/$name"

  if [ ! -f "$origin" ]; then
    say_warn "$name existe en .opencode/agents/ pero no en .claude/agents/"
    drift=$((drift + 1))
    continue
  fi

  pairs=$((pairs + 1))
  missing=""
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    if ! headings "$mirror" | grep -Fxq "$h"; then
      missing="${missing}
      · $h"
    fi
  done < <(headings "$origin")

  if [ -n "$missing" ]; then
    drift=$((drift + 1))
    say_warn "drift en $name — secciones del gemelo Claude ausentes en el espejo:$missing"
  fi
done

if [ "$drift" -eq 0 ]; then
  say_ok "espejo opencode sincronizado ($pairs agentes comparados)"
else
  say_warn "porta las secciones faltantes a .opencode/agents/ — el perfil opencode_go corre con esos prompts"
fi

exit 0
