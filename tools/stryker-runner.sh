#!/usr/bin/env bash
# stryker-runner.sh — Adaptador entre la convencion del arnes y el CLI de Stryker.
#
# POR QUE EXISTE
#
# El arnes llama al mutador asi:  bash tools/run-mutation.sh <archivo> [...]
# y run-mutation.sh reenvia los positionals a $HARNESS_MUTATION_CMD.
#
# Stryker NO acepta eso: su unico positional es el archivo de CONFIG, y los
# archivos a mutar van por `--mutate` (lista separada por comas). Sin esta
# traduccion, pasarle `src/utils/citizen/queryBuilder.js` lo hace buscar un
# archivo de configuracion con ese nombre y abortar.
#
# Vive en un script propio por la misma razon que test-node.sh: el conocimiento
# especifico de una herramienta va en el wrapper de esa herramienta, no
# desparramado en harness.config.sh ni en los wrappers genericos del kit.
#
# USO
#   bash tools/stryker-runner.sh                        # muta lo que diga el config
#   bash tools/stryker-runner.sh src/a.js src/b.js      # muta solo esos archivos
#   bash tools/stryker-runner.sh --reporters html src/a.js
#
# CONFIG (harness.config.sh o entorno)
#   HARNESS_MUTATION_CONCURRENCY  workers en paralelo. Default 2, a proposito.
#   HARNESS_MUTATION_THRESHOLD    umbral del gate; se contrasta con el config.
#   HARNESS_MEM_MAX               techo de RAM del arbol ENTERO de Stryker.

set -u
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/harness-env.sh" || exit 1

cd "$HARNESS_PROJECT_ROOT_ABS" || exit 1

# Binario local antes que npx/pnpm dlx: asi el script no depende de cual sea el
# gestor de paquetes del proyecto (este usa pnpm; otros, npm o yarn).
if [ -x "node_modules/.bin/stryker" ]; then
  STRYKER=(node_modules/.bin/stryker)
elif command -v npx >/dev/null 2>&1; then
  STRYKER=(npx --no-install stryker)
else
  echo "[stryker-runner] Stryker no esta instalado. Corre:" >&2
  echo "  pnpm add -D @stryker-mutator/core @stryker-mutator/tap-runner" >&2
  exit 1
fi

# Separar archivos a mutar (positionals) de flags, que van tal cual a Stryker.
#
# --config es NUESTRO, no de Stryker: en su CLI el archivo de configuracion es
# el unico POSICIONAL (`stryker run [configFile]`), y ese lugar ya lo usa el
# arnes para los archivos a mutar. Lo traducimos aca.
#
# Existe porque hay proyectos con un config por modulo, cada uno con su umbral,
# su testFilter y su runner (ej. ia_muni_frontend: stryker.gateway.json al 100%,
# stryker.conf.json al 85%, y configs de vitest distintas para web y backend).
# Sin esto el arnes solo podria usar el config por defecto.
MUTATE=""
CONFIG=""
PASSTHRU=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config)
      CONFIG="${2:-}"
      [ -n "$CONFIG" ] || { echo "[stryker-runner] --config necesita un archivo" >&2; exit 64; }
      shift 2
      ;;
    -*)
      PASSTHRU+=("$1")
      # Si el flag lleva valor (el siguiente no empieza con "-"), arrastrarlo.
      if [ "$#" -gt 1 ]; then
        case "$2" in
          -*) ;;
          *) PASSTHRU+=("$2"); shift ;;
        esac
      fi
      shift
      ;;
    *)
      MUTATE="${MUTATE:+$MUTATE,}$1"
      shift
      ;;
  esac
done

if [ -n "$CONFIG" ] && [ ! -f "$CONFIG" ]; then
  echo "[stryker-runner] No existe el config: $CONFIG" >&2
  exit 1
fi

# El umbral del gate vive en dos lados por fuerza mayor: el arnes lee
# HARNESS_MUTATION_THRESHOLD y Stryker solo acepta `thresholds.break` desde su
# archivo de config (no hay flag CLI). Avisar si se desincronizan es mas barato
# que descubrirlo cuando el gate deja pasar una feature que no deberia.
# Cual config va a leer Stryker: el que le pasamos, o el primero que autodetecta.
CFG_IN_USE="$CONFIG"
if [ -z "$CFG_IN_USE" ]; then
  for c in stryker.conf.json stryker.config.mjs stryker.config.js stryker.config.json \
           .stryker.conf.json .stryker.conf.js; do
    [ -f "$c" ] && { CFG_IN_USE="$c"; break; }
  done
fi

if [ -n "${HARNESS_MUTATION_THRESHOLD:-}" ] && [ -n "$CFG_IN_USE" ]; then
  # Sirve para JSON ("break": 100) y para JS/mjs (break: 100).
  BREAK_AT="$(grep -oE '"?break"?[[:space:]]*:[[:space:]]*[0-9]+' "$CFG_IN_USE" \
              | grep -oE '[0-9]+$' | head -1)"
  if [ -n "$BREAK_AT" ] && [ "$BREAK_AT" != "$HARNESS_MUTATION_THRESHOLD" ]; then
    echo "[stryker-runner] AVISO: HARNESS_MUTATION_THRESHOLD=$HARNESS_MUTATION_THRESHOLD" >&2
    echo "[stryker-runner]         pero $CFG_IN_USE tiene thresholds.break=$BREAK_AT." >&2
    echo "[stryker-runner]         Manda el config de Stryker: el exit code sale de ahi." >&2
  fi
fi

# Techo de memoria PROPIO de la mutacion. HARNESS_MEM_MAX (2G por defecto) esta
# pensado para UNA corrida de tests = un proceso node. Una corrida de mutacion
# son 1 + N procesos (Stryker + sus workers) dentro del mismo cgroup, asi que el
# techo del conjunto tiene que ser mayor o el runner se estrangula solo.
# Medido el 2026-08-21 sobre queryBuilder.js: workers legitimos de ~1.2 GB.
export HARNESS_MEM_MAX="${HARNESS_MUTATION_MEM_MAX:-4G}"

# Concurrency baja A PROPOSITO. Ver el comentario largo en stryker.config.mjs.
ARGS=(run)
[ -n "$CONFIG" ] && ARGS+=("$CONFIG")
ARGS+=(--concurrency "${HARNESS_MUTATION_CONCURRENCY:-2}")
[ -n "$MUTATE" ] && ARGS+=(--mutate "$MUTATE")
[ "${#PASSTHRU[@]}" -gt 0 ] && ARGS+=("${PASSTHRU[@]}")

# guard-mem.sh mete a TODO el arbol de Stryker (proceso padre + workers) en un
# solo cgroup con MemoryMax: el techo es del conjunto, no por proceso.
exec bash "$HARNESS_KIT_DIR/tools/guard-mem.sh" "${STRYKER[@]}" "${ARGS[@]}"
