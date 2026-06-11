#!/usr/bin/env bash
# test-affected.sh — Hook PostToolUse(Edit|Write): corre SOLO el test relevante
# al archivo recién editado, no la suite completa.
#
# Es la pieza de "test individual en el loop" (reducción de tokens/cómputo):
# el feedback rápido va aquí; la suite completa sigue corriendo en el gate de
# cierre (Stop -> init.sh paso 5), así no se pierde cobertura de regresiones.
#
# Lee el JSON del hook por stdin, saca .tool_input.file_path, resuelve su
# archivo de test (via HARNESS_TEST_FILE_PATTERNS) y delega en run-tests.sh.
# Si no puede mapear a un test, cae a la suite completa (seguro por defecto).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 0   # nunca bloqueamos al agente por un fallo del wrapper

[ -f "harness.config.sh" ] || { echo "[harness] sin config; salto"; exit 0; }
# shellcheck source=/dev/null
. ./harness.config.sh

PAYLOAD="$(cat)"

# --- 1. Extraer la ruta del archivo editado del JSON del hook ----------------
extract_path() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | python3 -c \
      'import sys,json;d=json.load(sys.stdin);print((d.get("tool_input") or {}).get("file_path",""))' 2>/dev/null
  elif command -v node >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | node -e \
      'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log((JSON.parse(s).tool_input||{}).file_path||"")}catch(e){console.log("")}})' 2>/dev/null
  else
    printf '%s' "$PAYLOAD" | grep -o '"file_path"[^,}]*' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//'
  fi
}

FILE="$(extract_path)"
# A ruta relativa al repo (los hooks suelen dar rutas absolutas).
case "$FILE" in
  "$HERE"/*) FILE="${FILE#"$HERE"/}" ;;
esac

run_full() { bash tools/run-tests.sh 2>&1 | tail -8; exit 0; }

# Sin archivo, sin comando de test único, o el editado no es de código: suite.
[ -n "$FILE" ] || run_full
case "${HARNESS_TEST_ONE_CMD:-}" in TODO*|"") run_full ;; esac

base="$(basename "$FILE")"
name="${base%.*}"
dir="$(dirname "$FILE")"

# --- 2. ¿El propio archivo editado ya es un test? ----------------------------
is_test_file=0
case "$base" in
  test_*|*_test.*|*.test.*|*.spec.*|*Test.*|*Spec.*) is_test_file=1 ;;
esac
case "$dir/" in
  "${HARNESS_TESTS_DIR:-tests}"/*|*/"${HARNESS_TESTS_DIR:-tests}"/*) is_test_file=1 ;;
esac

TESTFILE=""
if [ "$is_test_file" = "1" ]; then
  TESTFILE="$FILE"
else
  # --- 3. Mapear archivo FUENTE -> su archivo de test --------------------------
  for tmpl in ${HARNESS_TEST_FILE_PATTERNS:-}; do
    cand="${tmpl//\{name\}/$name}"
    cand="${cand//\{dir\}/$dir}"
    if [ -f "$cand" ]; then TESTFILE="$cand"; break; fi
  done
fi

# 4. Sin test mapeado -> suite completa (no perdemos seguridad).
[ -n "$TESTFILE" ] || run_full

echo "[harness] test individual: $TESTFILE"
bash tools/run-tests.sh --one "$TESTFILE" 2>&1 | tail -8
exit 0
