#!/usr/bin/env bash
# run-mutation.sh — Wrapper agnóstico para la prueba de mutación.
#
# Corre HARNESS_MUTATION_CMD sobre el/los archivo(s) indicados, desde la RAÍZ
# del proyecto y con el entorno del arnés cargado (HARNESS_KIT_DIR,
# HARNESS_TEST_CMD, etc. exportados), de modo que:
#   - el comando encuentra src/ y tests/ (cwd = raíz del proyecto), y
#   - mutate.py (si se usa) se localiza vía $HARNESS_KIT_DIR y lee HARNESS_TEST_CMD.
#
# Uso:
#   bash tools/run-mutation.sh <archivo> [args...]
#   bash tools/run-mutation.sh src/cli.py --max 80
set -u
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/harness-env.sh" || exit 1

CMD="${HARNESS_MUTATION_CMD:-}"
case "$CMD" in
  TODO*|"") echo "[harness] HARNESS_MUTATION_CMD sin definir en harness.config.sh" >&2; exit 1 ;;
esac

cd "$HARNESS_PROJECT_ROOT_ABS" || exit 1

# Mapa declarado módulo→tests (cabecera `covers:`). Si el archivo a mutar ($1)
# tiene tests que lo declaran, esos son el scope efectivo (scoping durable:
# sobrevive al cierre de la feat, no depende de HARNESS_FEAT_SCOPE). Guard: solo
# consultamos el mapa si $1 existe y es un archivo. Con mapa vacío (situación
# actual: ningún test tiene cabecera todavía) el scope efectivo cae a
# HARNESS_FEAT_SCOPE y el comportamiento es byte-idéntico al de antes.
MAPPED=""
if [ -n "${1:-}" ] && [ -f "$1" ]; then
  MAPPED="$(bash "$HARNESS_KIT_DIR/tools/test-map.sh" "$1" 2>/dev/null || true)"
fi

# Si hay scope de feat, pasarlo como --test-cmd al mutador (mucho más rápido:
# 1 archivo en vez de la suite completa por mutante). Si no, mutate.py lee
# $HARNESS_TEST_CMD como hasta hoy (suite completa = safe default).
# Scope efectivo: el mapa si no está vacío; si no, HARNESS_FEAT_SCOPE (como hoy).
SCOPE="${MAPPED:-${HARNESS_FEAT_SCOPE:-}}"
FEAT_TEST_CMD="${HARNESS_FEAT_TEST_CMD:-}"
MUTATION_TEST_CMD="${HARNESS_MUTATION_TEST_CMD:-}"

# Prioridad 1: comando de tests dedicado a la mutación (fail-fast, p.ej. -x de
# pytest). Es neutro para el veredicto (el mutante muere igual con el primer
# fallo) y mucho más rápido en los sobrevivientes. Se sustituye {scope} aunque
# $SCOPE esté vacío: en ese caso queda la suite completa con fail-fast, que
# sigue siendo un fallback seguro (no cambia el comportamiento de hoy salvo
# por el corte anticipado).
# ── Scope por git diff: mutar SOLO las lineas de la feature ─────────────
#
# El umbral del arnes (HARNESS_MUTATION_THRESHOLD) se define sobre las lineas
# NUEVAS O TOCADAS por la feature, no sobre el archivo entero. Mutar el archivo
# completo mezcla dos cosas distintas: los mutantes del codigo viejo sobreviven
# porque nadie escribio tests para el hace dos anios, hunden el score y no dicen
# NADA sobre la feature en curso. Medido el 2026-08-21 en queryBuilder.js:
# archivo completo 35.96% (gate rojo), lineas de la feature 100% (gate verde).
# El numero honesto es el segundo.
#
# HARNESS_MUTATION_RANGE_FMT declara como escribe rangos el mutador; vacio =
# no los soporta y los archivos van enteros (mutate.py, PIT, cargo-mutants).
# Stryker usa "{file}:{start}-{end}".
#
# HARNESS_MUTATION_DIFF_BASE es contra que se diffea. Default HEAD = el trabajo
# sin commitear. Si tu flujo hace commits a mitad de feature en una rama propia,
# poné la rama de integracion (p.ej. "origin/main") o un merge-base.
RANGE_FMT="${HARNESS_MUTATION_RANGE_FMT:-}"
DIFF_BASE="${HARNESS_MUTATION_DIFF_BASE:-HEAD}"

if [ -n "$RANGE_FMT" ] && [ "$#" -gt 0 ] && git rev-parse --git-dir >/dev/null 2>&1; then
  SCOPED=()
  _prev_was_flag=0
  for _f in "$@"; do
    # Valor de un flag (p.ej. `--config stryker.gateway.json`): pasa tal cual.
    # Sin esto intentariamos sacarle un rango de git al archivo de config, que
    # no es un objetivo de mutacion. Contracara: un flag booleano seguido de un
    # archivo (`--inPlace src/a.js`) deja a ese archivo sin rango — se muta
    # entero, que falla hacia el rojo. Si te pasa, pone los flags DESPUES de los
    # archivos o dale el rango explicito.
    if [ "$_prev_was_flag" = 1 ]; then
      SCOPED+=("$_f"); _prev_was_flag=0; continue
    fi
    case "$_f" in -*) SCOPED+=("$_f"); _prev_was_flag=1; continue ;; esac
    # Rango explicito del que llama: respetarlo, no pisarlo.
    case "$_f" in *:*) SCOPED+=("$_f"); continue ;; esac
    if [ ! -f "$_f" ]; then SCOPED+=("$_f"); continue; fi

    # Archivo nuevo sin trackear: TODO el archivo es de la feature. No es un
    # fallback, es la respuesta correcta.
    if ! git ls-files --error-unmatch -- "$_f" >/dev/null 2>&1; then
      SCOPED+=("$_f"); continue
    fi

    # De cada hunk `@@ -a,b +c,d @@` sale el rango c..c+d-1 del archivo NUEVO.
    # d=0 es un borrado puro: no hay lineas nuevas que mutar, se descarta.
    _hunks="$(git diff -U0 "$DIFF_BASE" -- "$_f" 2>/dev/null | awk '
      /^@@/ {
        plus = $3; sub(/^\+/, "", plus); split(plus, p, ",")
        start = p[1] + 0; count = (p[2] == "" ? 1 : p[2] + 0)
        if (count > 0) print start "-" (start + count - 1)
      }')"

    if [ -z "$_hunks" ]; then
      # SIN rango, NO sin mutantes. Un rango vacio le daria a Stryker cero
      # mutantes = score 100% = gate VERDE sobre cero evidencia, que es el peor
      # resultado posible. Caer al archivo entero falla hacia el rojo, que es
      # el lado seguro, y avisa fuerte para que se note.
      echo "[harness] AVISO: '$_f' no tiene cambios contra $DIFF_BASE." >&2
      echo "[harness]        Se muta el ARCHIVO ENTERO (incluye codigo viejo," >&2
      echo "[harness]        asi que el score va a ser pesimista). Si la feature" >&2
      echo "[harness]        ya esta commiteada, apuntá HARNESS_MUTATION_DIFF_BASE" >&2
      echo "[harness]        a la rama de integracion." >&2
      SCOPED+=("$_f")
    else
      for _h in $_hunks; do
        _r="${RANGE_FMT//\{file\}/$_f}"
        _r="${_r//\{start\}/${_h%-*}}"
        _r="${_r//\{end\}/${_h#*-}}"
        SCOPED+=("$_r")
      done
    fi
  done
  set -- "${SCOPED[@]}"
fi

# `--test-cmd` es un flag de tools/mutate.py (el mutador que trae el kit), NO un
# contrato universal de mutadores. Las herramientas nativas (Stryker, PIT,
# cargo-mutants, go-mutesting) sacan el comando de tests y el scope de SU PROPIO
# archivo de config, y ante un flag desconocido abortan. Hasta 2026-08-21 esto se
# inyectaba siempre, asi que HARNESS_MUTATION_CMD solo podia ser mutate.py:
# apuntarlo a Stryker fallaba en el arranque.
#
# Los wrappers por herramienta (tools/stryker-runner.sh y compania) traducen la
# convencion del kit a los flags de cada tool; ahi es donde vive ese conocimiento.
case "$CMD" in
  *mutate.py*) ACCEPTS_TEST_CMD=1 ;;
  *)           ACCEPTS_TEST_CMD=0 ;;
esac

if [ "$ACCEPTS_TEST_CMD" = 0 ]; then
  exec bash -c "$CMD \"\$@\"" _ "$@"
fi

if [ -n "$MUTATION_TEST_CMD" ]; then
  RESOLVED="${MUTATION_TEST_CMD//\{scope\}/$SCOPE}"
  exec bash -c "$CMD \"\$@\" --test-cmd \"$RESOLVED\"" _ "$@"
fi

# Prioridad 2 (comportamiento de hoy, sin cambios): si hay scope de feat,
# pasarlo como --test-cmd al mutador. Si no, mutate.py lee $HARNESS_TEST_CMD.
if [ -n "$SCOPE" ] && [ -n "$FEAT_TEST_CMD" ]; then
  RESOLVED="${FEAT_TEST_CMD//\{scope\}/$SCOPE}"
  exec bash -c "$CMD \"\$@\" --test-cmd \"$RESOLVED\"" _ "$@"
fi
exec bash -c "$CMD \"\$@\"" _ "$@"
