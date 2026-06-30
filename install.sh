#!/usr/bin/env bash
# install.sh — Instala (o ACTUALIZA) el Craftsman Harness Kit en un proyecto.
#
# Uso:
#   ./install.sh /ruta/a/tu/proyecto            # instala; no pisa archivos existentes
#   ./install.sh /ruta/a/tu/proyecto --force    # sobreescribe TODO (incluye tu estado)
#   ./install.sh /ruta/a/tu/proyecto --update   # actualiza SOLO la maquinaria del arnés
#   ./install.sh /ruta/a/tu/proyecto --migrate  # migra layout plano (viejo) → consolidado
#   ./install.sh /ruta/a/tu/proyecto --share-harness  # NO ignora el arnés en git
#   ./install.sh .                              # instala en el directorio actual
#
# --update vs --force vs --migrate:
#   --update reemplaza la MAQUINARIA (docs/, tools/, agentes, skills, init.sh,
#   settings.json, .claude/CLAUDE.md, AGENTS.md…) a la última versión del kit,
#   pero PRESERVA tu estado: feature_list.json, project-spec.md, progress/,
#   features/ y harness.config.sh. Hace backup de settings.json antes de tocarlo.
#   --force, en cambio, sobreescribe TODO (úsalo solo para re-sembrar de cero).
#   --migrate convierte un install VIEJO de layout plano (arnés en la raíz) al
#   layout consolidado (harness-kit/ + .claude/): hace backup .tgz, mueve tu
#   estado a harness-kit/, parcha harness.config.sh (PROJECT_ROOT + campos F1),
#   borra los archivos planos del arnés y refresca la maquinaria. Preserva tus
#   docs propios (docs/ no-arnés) y .claude/settings.local.json.
#
# Cada install/update queda anotado en un registro local del kit
# (.harness-installs) para poder actualizarlos todos con tools/update-all.sh.
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
#       ├── .harness-version     #   sello de versión instalada
#       └── AGENTS.md CHECKPOINTS.md QUICKSTART.md CLAUDE.md
#
# Nunca toca tu código (src/, tests/). Por defecto deja el arnés local-only.
set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
info() { printf "${BLUE}[..]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[skip]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

usage() { awk 'NR>1 && /^#/{sub(/^# ?/,"");print;next} NR>1{exit}' "$0"; }

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_SUBDIR="harness-kit"   # nombre de la carpeta consolidada en el proyecto
REGISTRY="$KIT_DIR/.harness-installs"   # registro local de instalaciones (gitignored)
KIT_VERSION="$(git -C "$KIT_DIR" rev-parse --short HEAD 2>/dev/null || date -u +%Y%m%d)"

# ── Argumentos ──────────────────────────────────────────────────────────
TARGET=""
FORCE=0
SHARE=0   # 0 = local-only (ignora el arnés en git); 1 = compartido (no ignora)
UPDATE=0  # 1 = modo actualización (refresca maquinaria, preserva estado)
MIGRATE=0 # 1 = migra layout plano (viejo) → consolidado
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --update) UPDATE=1 ;;
    --migrate) MIGRATE=1 ;;
    --share-harness) SHARE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

if [ -z "$TARGET" ]; then
  fail "Falta la ruta del proyecto destino."
  echo "Uso: ./install.sh /ruta/a/tu/proyecto [--update | --force] [--share-harness]"
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

# Docs que pertenecen al arnés (el resto de docs/ son del usuario y se preservan).
HARNESS_DOCS=( workflow tdd gherkin mutation-testing architecture conventions verification refactoring )

# ── Modo migración: layout plano (viejo) → consolidado ──────────────────
if [ "$MIGRATE" -eq 1 ]; then
  if [ -d "$KIT_DST" ]; then
    fail "Ya está consolidado (existe $KIT_SUBDIR/). Usa --update, no --migrate."; exit 1
  fi
  if [ ! -f "$TARGET/feature_list.json" ] && [ ! -f "$TARGET/AGENTS.md" ]; then
    fail "No detecto un install plano en $TARGET (sin feature_list.json/AGENTS.md en la raíz)."; exit 1
  fi
  info "Migrando layout plano → consolidado en: $TARGET"

  # 0. Backup .tgz de todo lo tocable (el arnés NO suele estar en git → imprescindible).
  TS="$(date -u +%Y%m%d-%H%M%S)"
  BACKUP=".harness-legacy-backup-$TS.tgz"
  BK_ITEMS=()
  for it in CLAUDE.md AGENTS.md CHECKPOINTS.md QUICKSTART.md init.sh \
            feature_list.json project-spec.md harness.config.sh \
            docs tools progress features .claude .gitignore; do
    [ -e "$TARGET/$it" ] && BK_ITEMS+=("$it")
  done
  ( cd "$TARGET" && tar czf "$BACKUP" "${BK_ITEMS[@]}" ) \
    && ok "Backup: $BACKUP (revierte con: tar xzf $BACKUP)" \
    || { fail "No pude crear el backup; aborto la migración."; exit 1; }

  # 1. harness-kit/ + mover ESTADO del usuario (no se re-siembra).
  mkdir -p "$KIT_DST"
  for s in feature_list.json project-spec.md harness.config.sh; do
    [ -f "$TARGET/$s" ] && mv "$TARGET/$s" "$KIT_DST/$s"
  done
  for d in progress features; do
    if [ -d "$TARGET/$d" ]; then
      mkdir -p "$KIT_DST/$d"
      # dotglob para arrastrar también ocultos (p. ej. .gitkeep); subshell para no filtrarlo.
      ( shopt -s dotglob nullglob; mv "$TARGET/$d"/* "$KIT_DST/$d"/ 2>/dev/null ) || true
      rmdir "$TARGET/$d" 2>/dev/null || true
    fi
  done

  # 2. Parchar harness.config.sh: PROJECT_ROOT=".." + campos F1 que falten.
  CFG="$KIT_DST/harness.config.sh"
  if [ -f "$CFG" ]; then
    PROFILE_M="$(
      if   [ -f "$TARGET/Cargo.toml" ]; then echo rust
      elif [ -f "$TARGET/go.mod" ];     then echo go
      elif [ -f "$TARGET/package.json" ]; then echo node
      elif [ -f "$TARGET/pyproject.toml" ] || [ -f "$TARGET/setup.py" ] || [ -f "$TARGET/requirements.txt" ]; then echo python
      else echo generic; fi )"
    PSRC="$KIT_DIR/profiles/$PROFILE_M.sh"
    {
      echo ""
      echo "# >>> migración a consolidado (campos agregados por install.sh --migrate) >>>"
      echo 'HARNESS_PROJECT_ROOT=".."'
      for v in HARNESS_TEST_ONE_CMD HARNESS_TEST_FILE_PATTERNS; do
        if ! grep -q "^$v=" "$CFG" && [ -f "$PSRC" ]; then grep "^$v=" "$PSRC"; fi
      done
      echo "# <<< migración <<<"
    } >> "$CFG"
    ok "harness.config.sh parchado (PROJECT_ROOT='..' + campos F1 del perfil $PROFILE_M)"
  fi

  # 3. Quitar la maquinaria PLANA de la raíz (los docs del usuario se preservan).
  for hd in "${HARNESS_DOCS[@]}"; do rm -f "$TARGET/docs/$hd.md"; done
  rmdir "$TARGET/docs" 2>/dev/null || true   # solo si quedó vacío (si hay docs propios, queda)
  rm -rf "$TARGET/tools"
  for f in CLAUDE.md AGENTS.md CHECKPOINTS.md QUICKSTART.md init.sh; do rm -f "$TARGET/$f"; done

  # A partir de aquí, reusar la rama de --update: fuerza maquinaria, preserva estado.
  UPDATE=1
fi

# ── Modo actualización: exige instalación previa y define qué se fuerza ──
if [ "$UPDATE" -eq 1 ] && [ "$MIGRATE" -ne 1 ]; then
  if [ ! -d "$KIT_DST" ]; then
    fail "No hay arnés instalado en $TARGET (falta $KIT_SUBDIR/). Corre install sin --update primero."
    exit 1
  fi
  info "Actualizando arnés en: $TARGET (versión kit → $KIT_VERSION)"
elif [ "$MIGRATE" -ne 1 ]; then
  info "Instalando arnés en: $TARGET ($KIT_SUBDIR/ + .claude/)"
fi

# La maquinaria se fuerza en --update o --force; el estado del usuario solo con --force.
MACH_FORCE=$FORCE
[ "$UPDATE" -eq 1 ] && MACH_FORCE=1
SEED_FORCE=$FORCE

# ── 1a. MAQUINARIA del arnés → harness-kit/ (se actualiza) ──────────────
KIT_MACHINERY=(
  "CLAUDE.md" "AGENTS.md" "CHECKPOINTS.md" "QUICKSTART.md" "init.sh"
  "docs/workflow.md" "docs/tdd.md" "docs/gherkin.md" "docs/mutation-testing.md"
  "docs/architecture.md" "docs/conventions.md" "docs/verification.md" "docs/refactoring.md"
  "tools/run-tests.sh" "tools/test-affected.sh" "tools/run-mutation.sh"
  "tools/harness-env.sh" "tools/mutate.py"
)

# ── 1a'. ESTADO del usuario → harness-kit/ (se PRESERVA en --update) ────
# Semillas: en la primera instalación se copian; en --update NO se tocan.
KIT_SEED=(
  "feature_list.json" "project-spec.md"
  "progress/current.md" "progress/history.md"
)

# ── 1b. Subagentes → .claude/agents/ (maquinaria) ───────────────────────
AGENT_FILES=(
  "craftsman_lead.md" "spec_partner.md" "gherkin_author.md" "tdd_craftsman.md"
  "judge.md" "mutation_tester.md" "harness_bootstrap.md"
)

# ── 1b'. Skills transversales → .claude/skills/ (maquinaria) ────────────
SKILL_FILES=(
  "commit-hygiene/SKILL.md" "branch-pr/SKILL.md" "progress-log/SKILL.md"
)

copy_one() {  # src dst force
  local src="$1" dst="$2" force="$3"
  if [ ! -f "$src" ]; then warn "no existe en el kit: ${src#"$KIT_DIR"/}"; return 1; fi
  if [ -f "$dst" ] && [ "$force" -ne 1 ]; then warn "ya existe (usa --force): ${dst#"$TARGET"/}"; return 2; fi
  mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; return 0
}

copied=0; skipped=0; preserved=0
for rel in "${KIT_MACHINERY[@]}"; do
  copy_one "$KIT_DIR/$rel" "$KIT_DST/$rel" "$MACH_FORCE"
  case $? in 0) copied=$((copied+1)) ;; 2) skipped=$((skipped+1)) ;; esac
done
for a in "${AGENT_FILES[@]}"; do
  copy_one "$KIT_DIR/.claude/agents/$a" "$CLAUDE_DST/agents/$a" "$MACH_FORCE"
  case $? in 0) copied=$((copied+1)) ;; 2) skipped=$((skipped+1)) ;; esac
done
for s in "${SKILL_FILES[@]}"; do
  copy_one "$KIT_DIR/.claude/skills/$s" "$CLAUDE_DST/skills/$s" "$MACH_FORCE"
  case $? in 0) copied=$((copied+1)) ;; 2) skipped=$((skipped+1)) ;; esac
done
# Estado del usuario: en --update se preserva (force=SEED_FORCE, no forzado).
for rel in "${KIT_SEED[@]}"; do
  if [ "$UPDATE" -eq 1 ] && [ -f "$KIT_DST/$rel" ]; then
    preserved=$((preserved+1)); continue
  fi
  copy_one "$KIT_DIR/$rel" "$KIT_DST/$rel" "$SEED_FORCE"
  case $? in 0) copied=$((copied+1)) ;; 2) skipped=$((skipped+1)) ;; esac
done

# features/ vacío con .gitkeep
mkdir -p "$KIT_DST/features"
[ -f "$KIT_DST/features/.gitkeep" ] || : > "$KIT_DST/features/.gitkeep"

ok "Archivos copiados: $copied (saltados: $skipped; estado preservado: $preserved)"

# ── 1c. .claude/settings.json (hooks → harness-kit/*) ───────────────────
# Reescribe las rutas del settings.json del kit (layout plano) al layout
# consolidado. Las reglas deny (Read(./node_modules/**)…) no llevan tools/ ni
# init.sh, así que no se tocan. En --update se hace backup antes de regenerar.
SETTINGS_DST="$CLAUDE_DST/settings.json"
if [ -f "$SETTINGS_DST" ] && [ "$MACH_FORCE" -ne 1 ]; then
  warn "ya existe (usa --force): .claude/settings.json"
else
  mkdir -p "$CLAUDE_DST"
  if [ "$UPDATE" -eq 1 ] && [ -f "$SETTINGS_DST" ]; then
    cp "$SETTINGS_DST" "$SETTINGS_DST.bak"
    info "backup: .claude/settings.json → settings.json.bak (revisa si lo habías personalizado)"
  fi
  sed -e "s|bash tools/|bash $KIT_SUBDIR/tools/|g" \
      -e "s|\\./init\\.sh|$KIT_SUBDIR/init.sh|g" \
      "$KIT_DIR/.claude/settings.json" > "$SETTINGS_DST"
  ok "Generado .claude/settings.json (hooks → $KIT_SUBDIR/)"
fi

# ── 1d. .claude/CLAUDE.md (puntero fino + regla de base) ────────────────
CLAUDE_MD_DST="$CLAUDE_DST/CLAUDE.md"
if [ -f "$CLAUDE_MD_DST" ] && [ "$MACH_FORCE" -ne 1 ]; then
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
# Siempre se PRESERVA en --update (es estado del proyecto). Solo --force regenera.
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
  echo "/.harness-legacy-backup-*.tgz"
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

# ── 5. Sello de versión + registro de la instalación ────────────────────
printf '%s\t%s\n' "$KIT_VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$KIT_DST/.harness-version"

record_install() {  # path version
  local path="$1" ver="$2" ts tmp
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp)"
  [ -f "$REGISTRY" ] && awk -F'\t' -v p="$path" '$1!=p' "$REGISTRY" > "$tmp"
  printf '%s\t%s\t%s\n' "$path" "$ver" "$ts" >> "$tmp"
  mv "$tmp" "$REGISTRY"
}
record_install "$TARGET" "$KIT_VERSION"
ok "Registrado en $(basename "$REGISTRY") (versión $KIT_VERSION)"

# ── 6. Siguiente paso ───────────────────────────────────────────────────
echo ""
echo "── Listo ────────────────────────────────────────────────"
if [ "$MIGRATE" -eq 1 ]; then
  ok "Arnés MIGRADO a layout consolidado en $TARGET/$KIT_SUBDIR/ (versión $KIT_VERSION)"
  echo "   Estado movido a $KIT_SUBDIR/: feature_list.json, project-spec.md, progress/, features/, harness.config.sh"
  echo "   Backup completo del layout viejo: $TARGET/$BACKUP"
  echo "   Tus docs propios (docs/ no-arnés) y .claude/settings.local.json quedaron intactos."
  echo ""
  echo "Siguiente paso:"
  echo "  1. cd $TARGET && $KIT_SUBDIR/init.sh   # debe terminar verde"
  echo "  2. Revisa $KIT_SUBDIR/harness.config.sh (los campos F1 agregados al final)."
  echo "  3. Si todo va bien, podés borrar el backup: rm $TARGET/$BACKUP"
elif [ "$UPDATE" -eq 1 ]; then
  ok "Arnés ACTUALIZADO en $TARGET/$KIT_SUBDIR/ (versión $KIT_VERSION)"
  echo "   Estado preservado: feature_list.json, project-spec.md, progress/, features/, harness.config.sh"
  [ -f "$SETTINGS_DST.bak" ] && echo "   settings.json regenerado; tu versión anterior quedó en settings.json.bak"
  echo ""
  echo "Siguiente paso:"
  echo "  1. cd $TARGET && $KIT_SUBDIR/init.sh   # debe terminar verde"
  echo "  2. Revisa git diff del arnés si lo versionas (--share-harness)."
else
  ok "Arnés instalado en $TARGET/$KIT_SUBDIR/ (+ .claude/ en la raíz)"
  [ "$SHARE" -eq 0 ] && echo "   (local-only: el repo del proyecto ignora el arnés; revisa con 'git status')"
  echo ""
  echo "Siguiente paso:"
  echo "  1. cd $TARGET            # abre Claude Code DESDE LA RAÍZ del proyecto"
  echo "  2. Revisa $KIT_SUBDIR/harness.config.sh (comandos de test/mutación/build)."
  echo "  3. $KIT_SUBDIR/init.sh   # debe terminar verde"
  echo "  4. En Claude Code pide: «Haz el bootstrap del arnés para este proyecto.»"
  echo "  5. Luego: «implementa la siguiente feature pendiente»"
fi
