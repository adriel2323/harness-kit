#!/usr/bin/env bash
# init.sh — Verificación e inicialización del entorno (AGNÓSTICO AL LENGUAJE).
#
# Lo ejecuta el agente al COMENZAR una sesión y antes de declarar cualquier
# tarea como `done`. Si falla, la sesión no debe avanzar.
#
# No asume ningún lenguaje: lee los comandos de `harness.config.sh`.
set -u
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

EXIT_CODE=0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE" || exit 1

# --fast: verificación intermedia con scope de feat (NO es gate de producción).
# Sin el flag (caso del Stop hook), corre la suite completa como siempre.
FAST=0
[ "${1:-}" = "--fast" ] && FAST=1

echo "── 1. Cargando configuración del arnés ────────────────"

if [ ! -f "harness.config.sh" ]; then
  fail "Falta harness.config.sh. Corre install.sh o copia un perfil: cp profiles/python.sh harness.config.sh"
  exit 1
fi
# shellcheck source=/dev/null
. ./harness.config.sh

# KIT_DIR = este directorio (config/tools/estado). PROJECT_ROOT = donde corren
# los tests (puede ser el padre si el arnés vive en harness-kit/). Exportadas
# para que los comandos que referencian el arnés (p. ej. mutate.py) resuelvan.
export HARNESS_KIT_DIR="$HERE"
PROJECT_ROOT_ABS="$(cd "$HERE/${HARNESS_PROJECT_ROOT:-.}" 2>/dev/null && pwd || echo "$HERE")"

if [ "${HARNESS_LANGUAGE:-TODO}" = "TODO" ] || [ -z "${HARNESS_LANGUAGE:-}" ]; then
  fail "HARNESS_LANGUAGE sin definir. Falta el bootstrap: edita harness.config.sh o pide «haz el bootstrap del arnés»."
  exit 1
fi
case "${HARNESS_TEST_CMD:-}" in
  TODO*|"") fail "HARNESS_TEST_CMD sin definir en harness.config.sh."; exit 1 ;;
esac
ok "Lenguaje: $HARNESS_LANGUAGE | tests: $HARNESS_TEST_CMD"

echo ""
echo "── 2. Verificando toolchain ────────────────────────────"
if [ -n "${HARNESS_RUNTIME_CHECK:-}" ]; then
  if eval "$HARNESS_RUNTIME_CHECK" >/dev/null 2>&1; then
    ok "Toolchain disponible ($HARNESS_RUNTIME_CHECK)"
  else
    fail "El toolchain no respondió: $HARNESS_RUNTIME_CHECK"
    EXIT_CODE=1
  fi
fi

echo ""
echo "── 3. Verificando archivos base del arnés ──────────────"
for f in AGENTS.md feature_list.json progress/current.md \
         docs/architecture.md docs/conventions.md docs/verification.md \
         docs/workflow.md CHECKPOINTS.md harness.config.sh; do
  if [ ! -f "$f" ]; then fail "Falta archivo base: $f"; EXIT_CODE=1; else ok "Existe $f"; fi
done

echo ""
echo "── 4. Validando feature_list.json y escenarios ────────"
# Validación portable: usa el primer runtime con JSON disponible; si no hay
# ninguno, hace una comprobación mínima por texto.
validate_with_python() { python3 - "$@" <<'PY'
import json, os, sys
try:
    data = json.load(open("feature_list.json"))
    valid = {"pending", "spec_ready", "in_progress", "done", "blocked"}
    feats = data["features"]
    in_progress = [f for f in feats if f["status"] == "in_progress"]
    if len(in_progress) > 1:
        print(f"[FAIL]  Hay {len(in_progress)} features en in_progress (máximo 1)"); sys.exit(1)
    requires_spec = {"spec_ready", "in_progress", "done"}
    errs = []
    for f in feats:
        if f["status"] not in valid:
            print(f"[FAIL]  Estado inválido en feature {f['id']}: {f['status']}"); sys.exit(1)
        if f.get("sdd") and f["status"] in requires_spec:
            ff = os.path.join("features", f["name"] + ".feature")
            if not os.path.isfile(ff):
                errs.append(f"feature {f['id']} ({f['name']}) en {f['status']} sin {ff}")
    if errs:
        for e in errs: print(f"[FAIL]  {e}")
        sys.exit(1)
    print(f"[OK]    feature_list.json válido ({len(feats)} features)")
except SystemExit: raise
except Exception as e:
    print(f"[FAIL]  feature_list.json inválido: {e}"); sys.exit(1)
PY
}

validate_with_node() { node - <<'JS'
const fs = require("fs");
try {
  const data = JSON.parse(fs.readFileSync("feature_list.json", "utf8"));
  const valid = new Set(["pending","spec_ready","in_progress","done","blocked"]);
  const feats = data.features;
  const inProg = feats.filter(f => f.status === "in_progress");
  if (inProg.length > 1) { console.log(`[FAIL]  Hay ${inProg.length} features en in_progress (máximo 1)`); process.exit(1); }
  const reqSpec = new Set(["spec_ready","in_progress","done"]);
  const errs = [];
  for (const f of feats) {
    if (!valid.has(f.status)) { console.log(`[FAIL]  Estado inválido en feature ${f.id}: ${f.status}`); process.exit(1); }
    if (f.sdd && reqSpec.has(f.status)) {
      const ff = `features/${f.name}.feature`;
      if (!fs.existsSync(ff)) errs.push(`feature ${f.id} (${f.name}) en ${f.status} sin ${ff}`);
    }
  }
  if (errs.length) { errs.forEach(e => console.log(`[FAIL]  ${e}`)); process.exit(1); }
  console.log(`[OK]    feature_list.json válido (${feats.length} features)`);
} catch (e) { console.log(`[FAIL]  feature_list.json inválido: ${e.message}`); process.exit(1); }
JS
}

if command -v python3 >/dev/null 2>&1; then
  validate_with_python || EXIT_CODE=1
elif command -v node >/dev/null 2>&1; then
  validate_with_node || EXIT_CODE=1
else
  COUNT=$(grep -c '"in_progress"' feature_list.json 2>/dev/null || echo 0)
  if [ "$COUNT" -gt 1 ]; then fail "Hay $COUNT features en in_progress (máximo 1)"; EXIT_CODE=1
  else warn "Sin python3/node: validación profunda de feature_list.json omitida (chequeo mínimo OK)"; fi
fi

echo ""
echo "── 5. Verificando perfil de modelos (model-map.yaml) ──"
if [ -f "model-map.yaml" ] && command -v python3 >/dev/null 2>&1; then
  PROFILE=$(python3 -c "import yaml;print(yaml.safe_load(open('model-map.yaml'))['active_profile'])" 2>/dev/null || echo "")
  if [ -n "$PROFILE" ]; then
    ok "Perfil activo: $PROFILE"
    if [ "$PROFILE" = "opencode_go" ]; then
      if command -v opencode >/dev/null 2>&1; then
        ok "opencode CLI disponible"
        # Verificar que los modelos referenciados existen.
        if python3 tools/resolve-model.py gherkin_author --field model >/dev/null 2>&1; then
          MODELS_OK=1
          for fase in gherkin_author tdd_craftsman mutation_tester harness_bootstrap; do
            M=$(python3 tools/resolve-model.py "$fase" --field model 2>/dev/null || echo "")
            if [ -z "$M" ]; then fail "No se resolvió modelo para fase '$fase'"; EXIT_CODE=1; MODELS_OK=0; fi
          done
          if [ "$MODELS_OK" = "1" ]; then ok "Modelos por fase resueltos vía resolve-model.py"; fi
        else
          warn "tools/resolve-model.py no corre (¿PyYAML?); el craftsman_lead caerá a fallback"
        fi
      else
        warn "active_profile=opencode_go pero 'opencode' no está en PATH; las fases híbridas fallarán"
      fi
    fi
  else
    warn "No se pudo leer active_profile de model-map.yaml"
  fi
fi

echo ""
echo "── 6. Ejecutando tests ─────────────────────────────────"
# Los tests corren en la raíz del proyecto (donde viven src/ y tests/).
# --fast + scope de feat  → solo el scope (verificación intermedia).
# --fast sin scope        → avisa y omite (no FAIL: es verificación intermedia).
# sin flag (Stop hook)    → suite completa = gate de producción (sin cambios).
if [ "$FAST" = "1" ] && [ -n "${HARNESS_FEAT_SCOPE:-}" ]; then
  CMD="${HARNESS_FEAT_TEST_CMD//\{scope\}/$HARNESS_FEAT_SCOPE}"
  if ( cd "$PROJECT_ROOT_ABS" && eval "$CMD" ) 2>&1; then
    ok "Tests del scope de feat pasan (--fast)"
  else
    fail "Tests del scope fallaron (--fast)"; EXIT_CODE=1
  fi
elif [ "$FAST" = "1" ]; then
  warn "--fast sin HARNESS_FEAT_SCOPE: paso de tests omitido (verificación intermedia)"
else
  if ( cd "$PROJECT_ROOT_ABS" && eval "$HARNESS_TEST_CMD" ) 2>&1; then
    ok "Todos los tests pasan"
  else
    fail "Hay tests rotos (o el comando de tests falló)"
    EXIT_CODE=1
  fi
fi

echo ""
echo "── 7. Resumen ──────────────────────────────────────────"
if [ $EXIT_CODE -eq 0 ]; then
  ok "Entorno listo. Puedes empezar a trabajar."
else
  fail "Entorno NO está listo. Resuelve los errores antes de avanzar."
fi
exit $EXIT_CODE
