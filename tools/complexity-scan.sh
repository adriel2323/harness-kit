#!/usr/bin/env bash
# complexity-scan.sh — Evidencia de complejidad sacada del historial de git.
#
# No usa LLM, no lee el contenido de los archivos y no necesita ninguna
# herramienta más allá de git + awk. Produce el insumo BARATO de la auditoría
# de complejidad (ver docs/complejidad.md y la skill `aposd-design`), para que
# el barrido de lectura —que sí cuesta— sepa dónde mirar.
#
# Dos métricas, y la segunda es la interesante:
#
#   CHURN     — cuántas veces se tocó cada archivo. Es el proxy empírico de
#               "cuánto cuesta el próximo cambio": un red flag grave en un
#               archivo que nadie toca hace tres años no es una prioridad.
#
#   CO-CAMBIO — qué archivos cambian JUNTOS en el mismo commit. Cuando dos
#               archivos que no se importan entre sí cambian juntos una y otra
#               vez, eso es AMPLIFICACIÓN DE CAMBIOS medida, no opinada: hay
#               una decisión de diseño que vive en dos lugares (filtración de
#               información, red flag #2). Es el detector más confiable que hay
#               y no cuesta nada.
#
# El ranking que importa es CHURN x SEVERIDAD del red flag, no el número de
# red flags. Este script da la primera mitad; el catálogo
# `.claude/skills/aposd-design/references/red-flags.md` da la segunda.
#
# Uso:
#   bash tools/complexity-scan.sh [--src <dir>] [--top <N>] [--since <fecha>]
#                                 [--max-commit-files <N>] [--min-pair <N>]
#
#   --src               Directorio a analizar. Por defecto HARNESS_SRC_DIR.
#   --top               Cuántas filas por sección (default 20).
#   --since             Acota el historial (ej. "2 years ago"). Default: todo.
#   --max-commit-files  Los commits que tocan MÁS de N archivos NO cuentan para
#                       co-cambio (default 25). Sin este filtro, un merge o un
#                       import inicial correlaciona medio repo con medio repo.
#                       El churn SÍ los cuenta: un refactor grande es churn real.
#   --min-pair          Umbral de ruido para co-cambio (default 3).
#   --exclude <regex>   Reemplaza el patrón de artefactos generados que se
#                       excluyen (ERE sobre la ruta). Por defecto saca
#                       __pycache__, node_modules, dist/build, .pyc, locks…:
#                       esos co-cambian con su fuente por construcción y
#                       ahogan la señal. Para no excluir nada: --exclude '^$'.
#
# Salida: reporte legible por stdout. Las advertencias van a stderr.
# Exit 0 siempre que pueda correr; 1 si no hay repo git o el dir no existe.
set -u
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/harness-env.sh" || exit 1

SRC_DIR="${HARNESS_SRC_DIR:-.}"
TOP=20
SINCE=""
MAX_COMMIT_FILES=25
MIN_PAIR=3

# Artefactos GENERADOS. Un .pyc cambia junto a su .py el 100% de las veces
# **por construcción**: es correlación garantizada, no acoplamiento de diseño.
# Si están versionados, saturan el ranking de co-cambio con pares de cero
# información y tapan la señal real. Se excluyen del scan (que estén en git es
# un problema aparte — el scan lo avisa, no lo arregla).
EXCLUDE_RE='(^|/)(__pycache__|node_modules|vendor|dist|build|target|coverage|\.venv|venv|\.next|\.tox|\.mypy_cache|\.pytest_cache)(/|$)'
EXCLUDE_RE="$EXCLUDE_RE"'|\.(pyc|pyo|class|jar|o|so|dylib|dll|exe|map|lock)$'
EXCLUDE_RE="$EXCLUDE_RE"'|(^|/)(package-lock\.json|pnpm-lock\.yaml|go\.sum)$'

while [ $# -gt 0 ]; do
  case "$1" in
    --src)              SRC_DIR="${2:-}";          shift 2 ;;
    --top)              TOP="${2:-}";              shift 2 ;;
    --since)            SINCE="${2:-}";            shift 2 ;;
    --max-commit-files) MAX_COMMIT_FILES="${2:-}"; shift 2 ;;
    --min-pair)         MIN_PAIR="${2:-}";         shift 2 ;;
    --exclude)          EXCLUDE_RE="${2:-}";       shift 2 ;;
    -h|--help)          sed -n '2,44p' "$0"; exit 0 ;;
    *) echo "[harness] complexity-scan.sh: opción desconocida: $1" >&2; exit 1 ;;
  esac
done

cd "$HARNESS_PROJECT_ROOT_ABS" || exit 1

git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "[harness] complexity-scan.sh: esto no es un repositorio git." >&2
  echo "          Sin historial no hay churn ni co-cambio: la auditoría" >&2
  echo "          arranca directo por el barrido de lectura." >&2
  exit 1
}

[ -d "$SRC_DIR" ] || {
  echo "[harness] complexity-scan.sh: no existe el directorio '$SRC_DIR'." >&2
  echo "          Revisa HARNESS_SRC_DIR en harness.config.sh o pasa --src." >&2
  exit 1
}

echo "── Auditoría de complejidad — evidencia de git ─────────────"
echo "   Directorio: $SRC_DIR${SINCE:+   ·   desde: $SINCE}"

# No truncar en silencio: si el repo versiona artefactos generados, decirlo.
N_ALL=$(git ls-files -- "$SRC_DIR" | grep -c . || true)
N_KEPT=$(git ls-files -- "$SRC_DIR" | grep -Ev "$EXCLUDE_RE" | grep -c . || true)
if [ "$N_ALL" -gt "$N_KEPT" ]; then
  printf "   [!] %d archivos generados excluidos del scan (están versionados:\n" \
         "$((N_ALL - N_KEPT))"
  printf "       revisá el .gitignore). Ajustable con --exclude.\n"
fi
echo ""

# Dos entradas al awk: (1) los archivos VIVOS —para no rankear código ya
# borrado—, (2) el log. El log sale como bloques: \x01<hash> y luego las rutas.
# shellcheck disable=SC2086
awk -v top="$TOP" -v maxf="$MAX_COMMIT_FILES" -v minpair="$MIN_PAIR" '
  # ── Entrada 1: archivos que todavía existen ──
  FNR == NR { alive[$0] = 1; next }

  # ── Entrada 2: el log ──
  /^\x01/ { flush(); n = 0; commits++; next }
  /^$/    { next }
  {
    if ($0 in alive) { cur[++n] = $0 }
    else             { raw_dead++ }
    next
  }
  END { flush(); report() }

  function flush(   i, j, a, b, key) {
    if (n == 0) return
    # Churn: cuenta todos los commits, incluidos los grandes. Un refactor de 40
    # archivos es churn real y el archivo efectivamente se tocó.
    for (i = 1; i <= n; i++) churn[cur[i]]++
    if (n > maxf) { big++; return }          # co-cambio: solo commits acotados
    if (n < 2) return
    for (i = 1; i < n; i++)
      for (j = i + 1; j <= n; j++) {
        a = cur[i]; b = cur[j]
        key = (a < b) ? a SUBSEP b : b SUBSEP a
        pair[key]++
      }
  }

  function report(   f, k, parts, i, cnt, out, pa, pb) {
    # ── Aviso: historial importado o aplastado ──
    nfiles = 0; for (f in churn) nfiles++
    if (nfiles == 0) {
      print "   (sin commits que toquen este directorio)"
      exit 0
    }
    if (big > 0 && commits > 0 && (big / commits) > 0.5)
      printf("   [!] %d de %d commits superan %d archivos. El historial parece\n" \
             "       importado o aplastado: el co-cambio va a decir poco.\n\n",
             big, commits, maxf) > "/dev/stderr"

    printf("   %d commits analizados · %d archivos vivos tocados", commits, nfiles)
    if (big > 0) printf(" · %d commits excluidos del co-cambio", big)
    printf("\n\n")

    # ── CHURN ──
    print  "── CHURN — cuánto se toca cada archivo ─────────────────────"
    print  "  commits  archivo"
    i = 0
    n_c = asorti_desc(churn, ord_c)
    for (k = 1; k <= n_c && i < top; k++) {
      printf("  %7d  %s\n", churn[ord_c[k]], ord_c[k]); i++
    }
    print ""

    # ── CO-CAMBIO ──
    print  "── CO-CAMBIO — qué cambia junto (amplificación medida) ─────"
    printf("  juntos   A→B   B→A  archivos\n")
    i = 0
    n_p = asorti_desc(pair, ord_p)
    for (k = 1; k <= n_p && i < top; k++) {
      cnt = pair[ord_p[k]]
      if (cnt < minpair) break
      split(ord_p[k], parts, SUBSEP)
      pa = churn[parts[1]] ? int(100 * cnt / churn[parts[1]]) : 0
      pb = churn[parts[2]] ? int(100 * cnt / churn[parts[2]]) : 0
      printf("  %6d  %4d%%  %4d%%  %s  ↔  %s\n", cnt, pa, pb, parts[1], parts[2])
      i++
    }
    if (i == 0) printf("  (ningún par supera el umbral de %d co-cambios)\n", minpair)
    print ""
    print  "  A→B se lee: \"cuando toco A, el N% de las veces también toco B\"."
    print  "  Un par alto entre archivos que NO se importan entre sí es"
    print  "  filtración de información (red flag #2): una decisión de diseño"
    print  "  que vive en dos lugares. Ese es el candidato a DDR."
  }

  # Orden descendente por valor. Sin asorti() de gawk, para correr en mawk/BWK.
  function asorti_desc(arr, out,   k, m, i, j, tmp) {
    m = 0
    for (k in arr) out[++m] = k
    for (i = 2; i <= m; i++) {                       # insertion sort
      tmp = out[i]; j = i - 1
      while (j > 0 && arr[out[j]] < arr[tmp]) { out[j+1] = out[j]; j-- }
      out[j+1] = tmp
    }
    return m
  }
' <(git ls-files -- "$SRC_DIR" | grep -Ev "$EXCLUDE_RE") \
  <(git log --no-merges --pretty=format:$'\x01%H' --name-only \
      ${SINCE:+--since="$SINCE"} -- "$SRC_DIR")

echo "── Siguiente paso ──────────────────────────────────────────"
echo "   Estos números dicen DÓNDE mirar, no QUÉ está mal. El barrido de"
echo "   lectura sobre los archivos de arriba (red flags del catálogo) es lo"
echo "   que produce los hallazgos. Ver docs/complejidad.md."
