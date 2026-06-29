#!/usr/bin/env bash
# install.sh — Instala el Craftsman Harness Kit en un proyecto, CONSOLIDADO.
#
# Uso:
#   ./install.sh /ruta/a/tu/proyecto            # no pisa archivos existentes
#   ./install.sh /ruta/a/tu/proyecto --force    # sobreescribe archivos del arnés
#   ./install.sh /ruta/a/tu/proyecto --share-harness  # NO ignora el arnés en git
#   ./install.sh .                              # instala en el directorio actual
#
# Qué produce (layout consolidado):
#   <proyecto>/
#   ├── .claude/                 # lo único que Claude Code exige en la raíz
#   │   ├── settings.json        #   hooks → harness-kit/* ; permisos ; deny rules
#   │   ├── CLAUDE.md            #   puntero fino: importa el arnés + regla de base
#   │   ├── agents/*.md          #   los 7 subagentes
#   │   └── skills/*/SKILL.md    #   skills transversales (commit-hygiene, branch-pr, progress-log)
#   └── harness-kit/             # TODO el resto del arnés, self-contained
#       ├── docs/ tools/ progress/ features/
#       ├── feature_list.json project-spec.md harness.config.sh init.sh
#       └── AGENTS.md CHECKPOINTS.md QUICKSTART.md CLAUDE.md
#
# Nunca toca tu código (src/, tests/). Por defecto deja el arnés local-only.
set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
info() { printf "${BLUE}[..]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[skip]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_SUBDIR="harness-kit"   # nombre de la carpeta consolidada en el proyecto

# ── Argumentos ──────────────────────────────────────────────────────────
TARGET=""
FORCE=0
SHARE=0   # 0 = local-only (ignora el arnés en git); 1 = compartido (no ignora)
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --share-harness) SHARE=1 ;;
    -h|--help) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

KIT_DST="$TARGET/$KIT_SUBDIR"     # <proyecto>/harness-kit
CLAUDE_DST="$TARGET/.claude"      # <proyecto>/.claude

info "Instalando arnés en: $TARGET ($KIT_SUBDIR/ + .claude/)"

# ── 1a. Archivos del arnés → harness-kit/ ───────────────────────────────
# (relativos al kit; van a <proyecto>/harness-kit/<rel>). harness.config.sh se
# genera aparte (§2).
KIT_FILES=(
  "CLAUDE.md" "AGENTS.md" "CHECKPOINTS.md" "QUICKSTART.md"
  "feature_list.json" "project-spec.md" "init.sh"
  "docs/workflow.md" "docs/tdd.md" "docs/gherkin.md" "docs/mutation-testing.md"
  "docs/architecture.md" "docs/conventions.md" "docs/verification.md" "docs/refactoring.md"
  "tools/run-tests.sh" "tools/test-affected.sh" "tools/run-mutation.sh"
  "tools/harness-env.sh" "tools/mutate.py"
  "progress/current.md" "progress/history.md"
)

# ── 1b. Subagentes → .claude/agents/ ────────────────────────────────────
AGENT_FILES=(
  "craftsman_lead.md" "spec_partner.md" "gherkin_author.md" "tdd_craftsman.md"
  "judge.md" "mutation_tester.md" "harness_bootstrap.md"
)

# ── 1b'. Skills transversales → .claude/skills/ ─────────────────────────
# (relativos a .claude/skills/; nativas de Claude Code, activadas por trigger)
SKILL_FILES=(
  "commit-hygiene/SKILL.md" "branch-pr/SKILL.md" "progress-log/SKILL.md"
)

copy_one() {  # src dst
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then warn "no existe en el kit: ${src#"$KIT_DIR"/}"; return 1; fi
  if [ -f "$dst" ] && [ "$FORCE" -ne 1 ]; then warn "ya existe (usa --force): ${dst#"$TARGET"/}"; return 2; fi
  mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; return 0
}

copied=0; skipped=0
for rel in "${KIT_FILES[@]}"; do
  copy_one "$KIT_DIR/$rel" "$KIT_DST/$rel"
  case $? in 0) copied=$((copied+1)) ;; 2) skipped=$((skipped+1)) ;; esac
done
for a in "${AGENT_FILES[@]}"; do
  copy_one "$KIT_DIR/.claude/agents/$a" "$CLAUDE_DST/agents/$a"
  case $? in 0) copied=$((copied+1)) ;; 2) skipped=$((skipped+1)) ;; esac
done
for s in "${SKILL_FILES[@]}"; do
  copy_one "$KIT_DIR/.claude/skills/$s" "$CLAUDE_DST/skills/$s"
  case $? in 0) copied=$((copied+1)) ;; 2) skipped=$((skipped+1)) ;; esac
done

# features/ vacío con .gitkeep
mkdir -p "$KIT_DST/features"
[ -f "$KIT_DST/features/.gitkeep" ] || : > "$KIT_DST/features/.gitkeep"

ok "Archivos copiados: $copied (saltados: $skipped)"

# ── 1c. .claude/settings.json (hooks → harness-kit/*) ───────────────────
# Reescribe las rutas del settings.json del kit (layout plano) al layout
# consolidado. Las reglas deny (Read(./node_modules/**)…) no llevan tools/ ni
# init.sh, así que no se tocan.
SETTINGS_DST="$CLAUDE_DST/settings.json"
if [ -f "$SETTINGS_DST" ] && [ "$FORCE" -ne 1 ]; then
  warn "ya existe (usa --force): .claude/settings.json"
else
  mkdir -p "$CLAUDE_DST"
  sed -e "s|bash tools/|bash $KIT_SUBDIR/tools/|g" \
      -e "s|\\./init\\.sh|$KIT_SUBDIR/init.sh|g" \
      "$KIT_DIR/.claude/settings.json" > "$SETTINGS_DST"
  ok "Generado .claude/settings.json (hooks → $KIT_SUBDIR/)"
fi

# ── 1d. .claude/CLAUDE.md (puntero fino + regla de base) ────────────────
CLAUDE_MD_DST="$CLAUDE_DST/CLAUDE.md"
if [ -f "$CLAUDE_MD_DST" ] && [ "$FORCE" -ne 1 ]; then
  warn "ya existe (usa --force): .claude/CLAUDE.md"
else
  mkdir -p "$CLAUDE_DST"
  cat > "$CLAUDE_MD_DST" <<EOF
# Arnés Craftsman — puntero

Este proyecto usa el Craftsman Harness Kit, **consolidado en \`$KIT_SUBDIR/\`**.
Claude Code solo exige \`.claude/\` y este \`CLAUDE.md\` en la raíz; todo lo demás
del arnés vive en \`$KIT_SUBDIR/\`.

## Regla de base de rutas (IMPORTANTE)

Las rutas de **artefactos del arnés** son relativas a \`$KIT_SUBDIR/\`:
\`docs/\`, \`progress/\`, \`features/\`, \`feature_list.json\`, \`project-spec.md\`,
\`harness.config.sh\`, \`CHECKPOINTS.md\`, \`tools/\`, \`init.sh\`. Cuando un agente o
doc mencione una de esas rutas sin prefijo, interprétala bajo \`$KIT_SUBDIR/\`
(p. ej. \`feature_list.json\` → \`$KIT_SUBDIR/feature_list.json\`).

En particular, los **comandos** del arnés llevan el prefijo: \`./init.sh\` →
\`$KIT_SUBDIR/init.sh\`; \`tools/...\` → \`$KIT_SUBDIR/tools/...\`.

El **código del proyecto** (\`src/\`, \`tests/\`, según \`HARNESS_SRC_DIR\` /
\`HARNESS_TESTS_DIR\`) vive en la **raíz** del proyecto, sin prefijo.

Los hooks y scripts ya resuelven esto solos (separan KIT_DIR de PROJECT_ROOT vía
\`HARNESS_PROJECT_ROOT\`); esta regla es para tu interpretación de la prosa.

## Instrucciones del rol (importadas)

@../$KIT_SUBDIR/CLAUDE.md
EOF
  ok "Generado .claude/CLAUDE.md (puntero → $KIT_SUBDIR/CLAUDE.md)"
fi

# ── 2. Detectar lenguaje y escribir harness-kit/harness.config.sh ───────
detect_profile() {
  if   [ -f "$TARGET/Cargo.toml" ];                                   then echo "rust"
  elif [ -f "$TARGET/go.mod" ];                                       then echo "go"
  elif [ -f "$TARGET/package.json" ];                                 then echo "node"
  elif [ -f "$TARGET/pyproject.toml" ] || [ -f "$TARGET/setup.py" ] \
       || [ -f "$TARGET/requirements.txt" ];                          then echo "python"
  else echo "generic"; fi
}

CONFIG_DST="$KIT_DST/harness.config.sh"
if [ -f "$CONFIG_DST" ] && [ "$FORCE" -ne 1 ]; then
  warn "harness.config.sh ya existe (usa --force para regenerar) — lo respeto"
else
  PROFILE="$(detect_profile)"
  PROFILE_SRC="$KIT_DIR/profiles/$PROFILE.sh"
  if [ -f "$PROFILE_SRC" ]; then
    # El arnés vive en harness-kit/, así que la raíz del proyecto es el padre.
    sed 's|^HARNESS_PROJECT_ROOT=.*|HARNESS_PROJECT_ROOT=".."|' "$PROFILE_SRC" > "$CONFIG_DST"
    ok "Lenguaje detectado: $PROFILE → $KIT_SUBDIR/harness.config.sh (PROJECT_ROOT='..')"
    [ "$PROFILE" = "generic" ] && warn "Perfil genérico: edita harness.config.sh (TODO) o corre el bootstrap."
  else
    fail "Falta el perfil $PROFILE.sh en el kit."
  fi
fi

# ── 3. Local-only: gestionar el .gitignore del proyecto ─────────────────
GI_START="# >>> craftsman-harness (local-only, gestionado por install.sh) >>>"
GI_END="# <<< craftsman-harness <<<"

build_ignore_block() {
  echo "$GI_START"
  echo "# Quita estas líneas (o instala con --share-harness) si quieres versionar el arnés."
  echo "/$KIT_SUBDIR/"
  echo "/.claude/settings.json"
  echo "/.claude/CLAUDE.md"
  for a in "${AGENT_FILES[@]}"; do echo "/.claude/agents/$a"; done
  for s in "${SKILL_FILES[@]}"; do echo "/.claude/skills/$s"; done
  echo "$GI_END"
}

if [ "$SHARE" -eq 1 ]; then
  info "--share-harness: el arnés NO se añade al .gitignore (se versionará con el proyecto)."
else
  GI="$TARGET/.gitignore"
  TMP_GI="$(mktemp)"
  if [ -f "$GI" ]; then
    awk -v s="$GI_START" -v e="$GI_END" '$0==s{skip=1} skip!=1{print} $0==e{skip=0}' "$GI" > "$TMP_GI"
    if [ -s "$TMP_GI" ] && [ -n "$(tail -c1 "$TMP_GI")" ]; then printf "\n" >> "$TMP_GI"; fi
    [ -s "$TMP_GI" ] && printf "\n" >> "$TMP_GI"
  fi
  build_ignore_block >> "$TMP_GI"
  mv "$TMP_GI" "$GI"
  ok "Arnés marcado como local-only en $TARGET/.gitignore (usa --share-harness para versionarlo)"
fi

# ── 4. Permisos de ejecución ────────────────────────────────────────────
chmod +x "$KIT_DST/init.sh" 2>/dev/null || true
for s in run-tests.sh test-affected.sh run-mutation.sh harness-env.sh; do
  chmod +x "$KIT_DST/tools/$s" 2>/dev/null || true
done

# ── 5. Siguiente paso ───────────────────────────────────────────────────
echo ""
echo "── Listo ────────────────────────────────────────────────"
ok "Arnés instalado en $TARGET/$KIT_SUBDIR/ (+ .claude/ en la raíz)"
[ "$SHARE" -eq 0 ] && echo "   (local-only: el repo del proyecto ignora el arnés; revisa con 'git status')"
echo ""
echo "Siguiente paso:"
echo "  1. cd $TARGET            # abre Claude Code DESDE LA RAÍZ del proyecto"
echo "  2. Revisa $KIT_SUBDIR/harness.config.sh (comandos de test/mutación/build)."
echo "  3. $KIT_SUBDIR/init.sh   # debe terminar verde"
echo "  4. En Claude Code pide: «Haz el bootstrap del arnés para este proyecto.»"
echo "  5. Luego: «implementa la siguiente feature pendiente»"
