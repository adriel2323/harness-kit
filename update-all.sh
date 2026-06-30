#!/usr/bin/env bash
# update-all.sh — Actualiza el Craftsman Harness en TODOS los proyectos donde lo
# instalaste, leyendo el registro local del kit (.harness-installs).
#
# Uso:
#   ./update-all.sh            # actualiza cada proyecto registrado (install.sh --update)
#   ./update-all.sh --list     # solo lista las instalaciones registradas y su versión
#   ./update-all.sh --dry-run  # muestra qué actualizaría, sin tocar nada
#   ./update-all.sh --prune    # quita del registro las rutas que ya no existen
#
# Cada proyecto se actualiza con `install.sh <ruta> --update`, que refresca la
# MAQUINARIA (docs/, tools/, agentes, skills, settings.json…) y PRESERVA tu
# estado (feature_list.json, project-spec.md, progress/, features/,
# harness.config.sh). El registro lo alimenta el propio install.sh.
set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
info() { printf "${BLUE}[..]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[skip]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="$KIT_DIR/.harness-installs"
INSTALL="$KIT_DIR/install.sh"
KIT_SUBDIR="harness-kit"
KIT_VERSION="$(git -C "$KIT_DIR" rev-parse --short HEAD 2>/dev/null || date -u +%Y%m%d)"

MODE="update"   # update | list | dry-run | prune
for arg in "$@"; do
  case "$arg" in
    --list)    MODE="list" ;;
    --dry-run) MODE="dry-run" ;;
    --prune)   MODE="prune" ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) fail "Argumento desconocido: $arg"; exit 1 ;;
  esac
done

if [ ! -f "$REGISTRY" ] || [ ! -s "$REGISTRY" ]; then
  info "No hay instalaciones registradas todavía ($(basename "$REGISTRY") vacío o ausente)."
  echo "   Instala en algún proyecto con: ./install.sh /ruta/a/tu/proyecto"
  exit 0
fi

# Sello de versión instalado en un proyecto (1ª columna de .harness-version).
installed_version() {  # path
  local vf="$1/$KIT_SUBDIR/.harness-version"
  [ -f "$vf" ] && cut -f1 "$vf" | head -1 || echo "?"
}

# ── --list ──────────────────────────────────────────────────────────────
if [ "$MODE" = "list" ]; then
  info "Versión actual del kit: $KIT_VERSION"
  echo ""
  printf "%-3s %-10s %-10s %s\n" "" "INSTALADA" "REGISTRO" "PROYECTO"
  while IFS=$'\t' read -r path ver ts; do
    [ -z "$path" ] && continue
    if [ -d "$path/$KIT_SUBDIR" ]; then mark="✓"; iv="$(installed_version "$path")"
    elif [ -d "$path" ];            then mark="~"; iv="(sin arnés)"
    else                                 mark="✗"; iv="(no existe)"; fi
    printf "%-3s %-10s %-10s %s\n" "$mark" "$iv" "$ver" "$path"
  done < "$REGISTRY"
  echo ""
  echo "  ✓ instalado   ~ ruta existe sin arnés   ✗ ruta no existe"
  exit 0
fi

# ── --prune ─────────────────────────────────────────────────────────────
if [ "$MODE" = "prune" ]; then
  tmp="$(mktemp)"; removed=0
  while IFS=$'\t' read -r path ver ts; do
    [ -z "$path" ] && continue
    if [ -d "$path" ]; then printf '%s\t%s\t%s\n' "$path" "$ver" "$ts" >> "$tmp"
    else warn "fuera del registro (no existe): $path"; removed=$((removed+1)); fi
  done < "$REGISTRY"
  mv "$tmp" "$REGISTRY"
  ok "Prune completo: $removed ruta(s) eliminada(s) del registro."
  exit 0
fi

# ── update / dry-run ────────────────────────────────────────────────────
[ -x "$INSTALL" ] || { fail "No encuentro install.sh ejecutable en $KIT_DIR"; exit 1; }

total=0; updated=0; failed=0; missing=0
while IFS=$'\t' read -r path ver ts; do
  [ -z "$path" ] && continue
  total=$((total+1))
  if [ ! -d "$path" ]; then
    warn "no existe (usa --prune para quitarla): $path"; missing=$((missing+1)); continue
  fi
  if [ ! -d "$path/$KIT_SUBDIR" ]; then
    warn "la ruta existe pero no tiene el arnés ($KIT_SUBDIR/): $path"; missing=$((missing+1)); continue
  fi
  if [ "$MODE" = "dry-run" ]; then
    info "actualizaría: $path  ($(installed_version "$path") → $KIT_VERSION)"; continue
  fi
  info "── Actualizando: $path"
  if bash "$INSTALL" "$path" --update; then updated=$((updated+1))
  else fail "falló la actualización de: $path"; failed=$((failed+1)); fi
done < "$REGISTRY"

echo ""
echo "── Resumen ──────────────────────────────────────────────"
if [ "$MODE" = "dry-run" ]; then
  info "Dry-run: $total registradas (omitidas por inexistentes: $missing). Nada modificado."
else
  ok "Actualizadas: $updated/$total  (fallidas: $failed; omitidas: $missing)"
  [ "$missing" -gt 0 ] && echo "   Corre ./update-all.sh --prune para limpiar rutas inexistentes."
fi
