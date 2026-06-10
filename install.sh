#!/usr/bin/env bash
# install.sh — Instala el Craftsman Harness Kit en la raíz de un proyecto.
#
# Uso:
#   ./install.sh /ruta/a/tu/proyecto            # no pisa archivos existentes
#   ./install.sh /ruta/a/tu/proyecto --force    # sobreescribe archivos del arnés
#   ./install.sh /ruta/a/tu/proyecto --share-harness  # NO ignora el arnés en git
#   ./install.sh .                              # instala en el directorio actual
#
# Qué hace:
#   1. Copia los archivos del arnés a la raíz del proyecto (nunca toca tu código).
#   2. Detecta el lenguaje y escribe harness.config.sh desde el perfil adecuado.
#   3. Por defecto, deja el arnés LOCAL-ONLY: añade un bloque gestionado al
#      .gitignore del proyecto para que su repo no versione el arnés.
#   4. Deja init.sh y los scripts ejecutables e imprime el siguiente paso.
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
SHARE=0   # 0 = local-only (ignora el arnés en git); 1 = compartido (no ignora)
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --share-harness) SHARE=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

if [ -z "$TARGET" ]; then
  fail "Falta la ruta del proyecto destino."
  echo "Uso: ./install.sh /ruta/a/tu/proyecto [--force] [--share-harness]"
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
# README.md, INSTALL.md, profiles/, .gitignore ni harness.config.sh (este
# último se genera; el .gitignore del proyecto no se pisa, se gestiona — §3).
HARNESS_PATHS=(
  "CLAUDE.md" "AGENTS.md" "CHECKPOINTS.md" "feature_list.json"
  "project-spec.md" "init.sh"
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

# ── 3. Local-only: gestionar el .gitignore del proyecto ─────────────────
# Por defecto el arnés NO se versiona en el repo del proyecto: es parte del
# ecosistema de desarrollo local de quien lo usa. Añadimos un bloque gestionado
# (idempotente, entre marcadores) al .gitignore del proyecto con TODAS las rutas
# que instalamos o generamos. Con --share-harness se omite este paso.
GI_START="# >>> craftsman-harness (local-only, gestionado por install.sh) >>>"
GI_END="# <<< craftsman-harness <<<"

build_ignore_block() {
  echo "$GI_START"
  echo "# Quita estas líneas (o instala con --share-harness) si quieres versionar el arnés."
  # Archivos del arnés (raíz, .claude/, docs/, tools/). Las rutas de progress/
  # y features/ se ignoran a nivel de carpeta más abajo (atrapan lo generado).
  for rel in "${HARNESS_PATHS[@]}"; do
    case "$rel" in
      progress/*|features/*) continue ;;
    esac
    echo "/$rel"
  done
  echo "/harness.config.sh"
  echo "/progress/"
  echo "/features/"
  echo "$GI_END"
}

if [ "$SHARE" -eq 1 ]; then
  info "--share-harness: el arnés NO se añade al .gitignore (se versionará con el proyecto)."
else
  GI="$TARGET/.gitignore"
  TMP_GI="$(mktemp)"
  if [ -f "$GI" ]; then
    # Elimina cualquier bloque previo (entre marcadores) para reescribirlo limpio.
    awk -v s="$GI_START" -v e="$GI_END" '
      $0==s {skip=1}
      skip!=1 {print}
      $0==e {skip=0}
    ' "$GI" > "$TMP_GI"
    # Asegura una línea en blanco de separación si el archivo no termina vacío.
    if [ -s "$TMP_GI" ] && [ -n "$(tail -c1 "$TMP_GI")" ]; then printf "\n" >> "$TMP_GI"; fi
    [ -s "$TMP_GI" ] && printf "\n" >> "$TMP_GI"
  fi
  build_ignore_block >> "$TMP_GI"
  mv "$TMP_GI" "$GI"
  ok "Arnés marcado como local-only en $TARGET/.gitignore (usa --share-harness para versionarlo)"
fi

# ── 4. Permisos de ejecución ────────────────────────────────────────────
chmod +x "$TARGET/init.sh" 2>/dev/null || true
chmod +x "$TARGET/tools/run-tests.sh" 2>/dev/null || true

# ── 5. Siguiente paso ───────────────────────────────────────────────────
echo ""
echo "── Listo ────────────────────────────────────────────────"
ok "Arnés instalado en $TARGET"
if [ "$SHARE" -eq 0 ]; then
  echo "   (local-only: el repo del proyecto ignora el arnés; revisa con 'git status')"
fi
echo ""
echo "Siguiente paso:"
echo "  1. cd $TARGET"
echo "  2. Revisa harness.config.sh (comandos de test/mutación/build)."
echo "  3. ./init.sh    # debe terminar verde"
echo "  4. Abre Claude Code y pide: «Haz el bootstrap del arnés para este proyecto.»"
echo "     (personaliza docs/architecture.md y docs/conventions.md a tu stack)"
echo "  5. Luego: «implementa la siguiente feature pendiente»"
