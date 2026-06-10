#!/usr/bin/env bash
# install.sh — Instala el Craftsman Harness Kit en la raíz de un proyecto.
#
# Uso:
#   ./install.sh /ruta/a/tu/proyecto            # no pisa archivos existentes
#   ./install.sh /ruta/a/tu/proyecto --force    # sobreescribe archivos del arnés
#   ./install.sh .                              # instala en el directorio actual
#
# Qué hace:
#   1. Copia los archivos del arnés a la raíz del proyecto (nunca toca tu código).
#   2. Detecta el lenguaje y escribe harness.config.sh desde el perfil adecuado.
#   3. Deja init.sh y los scripts ejecutables e imprime el siguiente paso.
set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
info() { printf "${BLUE}[..]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[skip]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Argumentos ──────────────────────────────────────────────────────────
TARGET=""
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

if [ -z "$TARGET" ]; then
  fail "Falta la ruta del proyecto destino."
  echo "Uso: ./install.sh /ruta/a/tu/proyecto [--force]"
  exit 1
fi

mkdir -p "$TARGET" || { fail "No pude crear/abrir $TARGET"; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

if [ "$TARGET" = "$KIT_DIR" ]; then
  fail "El destino es la propia carpeta del kit. Elige tu proyecto."
  exit 1
fi

info "Instalando arnés en: $TARGET"

# ── 1. Copiar archivos del arnés ────────────────────────────────────────
# Lista de rutas (relativas al kit) que forman el arnés. NO incluye install.sh,
# README.md, INSTALL.md, profiles/ ni harness.config.sh (este último se genera).
HARNESS_PATHS=(
  "CLAUDE.md" "AGENTS.md" "CHECKPOINTS.md" "feature_list.json"
  "project-spec.md" "init.sh" ".gitignore"
  ".claude/settings.json"
  ".claude/agents/craftsman_lead.md" ".claude/agents/spec_partner.md"
  ".claude/agents/gherkin_author.md" ".claude/agents/tdd_craftsman.md"
  ".claude/agents/judge.md" ".claude/agents/mutation_tester.md"
  ".claude/agents/harness_bootstrap.md"
  "docs/workflow.md" "docs/tdd.md" "docs/gherkin.md"
  "docs/mutation-testing.md" "docs/architecture.md" "docs/conventions.md"
  "docs/verification.md"
  "tools/run-tests.sh" "tools/mutate.py"
  "progress/current.md" "progress/history.md"
)

copied=0; skipped=0
for rel in "${HARNESS_PATHS[@]}"; do
  src="$KIT_DIR/$rel"
  dst="$TARGET/$rel"
  if [ ! -f "$src" ]; then
    warn "no existe en el kit: $rel"
    continue
  fi
  if [ -f "$dst" ] && [ "$FORCE" -ne 1 ]; then
    warn "ya existe (usa --force): $rel"
    skipped=$((skipped + 1))
    continue
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  copied=$((copied + 1))
done

# features/ vacío con .gitkeep
mkdir -p "$TARGET/features"
[ -f "$TARGET/features/.gitkeep" ] || : > "$TARGET/features/.gitkeep"

ok "Archivos copiados: $copied (saltados: $skipped)"

# ── 2. Detectar lenguaje y escribir harness.config.sh ───────────────────
detect_profile() {
  if   [ -f "$TARGET/Cargo.toml" ];                                   then echo "rust"
  elif [ -f "$TARGET/go.mod" ];                                       then echo "go"
  elif [ -f "$TARGET/package.json" ];                                 then echo "node"
  elif [ -f "$TARGET/pyproject.toml" ] || [ -f "$TARGET/setup.py" ] \
       || [ -f "$TARGET/requirements.txt" ];                          then echo "python"
  else echo "generic"; fi
}

CONFIG_DST="$TARGET/harness.config.sh"
if [ -f "$CONFIG_DST" ] && [ "$FORCE" -ne 1 ]; then
  warn "harness.config.sh ya existe (usa --force para regenerar) — lo respeto"
else
  PROFILE="$(detect_profile)"
  PROFILE_SRC="$KIT_DIR/profiles/$PROFILE.sh"
  if [ -f "$PROFILE_SRC" ]; then
    cp "$PROFILE_SRC" "$CONFIG_DST"
    ok "Lenguaje detectado: $PROFILE → harness.config.sh"
    if [ "$PROFILE" = "generic" ]; then
      warn "Perfil genérico: edita harness.config.sh (marcadores TODO) o corre el bootstrap."
    fi
  else
    fail "Falta el perfil $PROFILE.sh en el kit."
  fi
fi

# ── 3. Permisos de ejecución ────────────────────────────────────────────
chmod +x "$TARGET/init.sh" 2>/dev/null || true
chmod +x "$TARGET/tools/run-tests.sh" 2>/dev/null || true

# ── 4. Siguiente paso ───────────────────────────────────────────────────
echo ""
echo "── Listo ────────────────────────────────────────────────"
ok "Arnés instalado en $TARGET"
echo ""
echo "Siguiente paso:"
echo "  1. cd $TARGET"
echo "  2. Revisa harness.config.sh (comandos de test/mutación/build)."
echo "  3. ./init.sh    # debe terminar verde"
echo "  4. Abre Claude Code y pide: «Haz el bootstrap del arnés para este proyecto.»"
echo "     (personaliza docs/architecture.md y docs/conventions.md a tu stack)"
echo "  5. Luego: «implementa la siguiente feature pendiente»"
