#!/usr/bin/env bash
# guard-mem.sh — Corre un comando con techo de memoria en su propio cgroup.
#
# POR QUE EXISTE (2026-08-21): un `node --test` huerfano de mutation testing
# crecio a 10.1 GB de RSS y agoto los 16 GB de swap. Como en WSL todo lo lanzado
# desde la terminal vive en `init.scope` y systemd traia OOMPolicy=stop, el OOM
# killer se llevo puesto el scope ENTERO: la terminal, todas las sesiones de
# claude y docker. Costo: una sesion de maquina.
#
# Un proceso de tests no tiene ninguna razon legitima para pasar de un par de
# GB. Ponerle techo convierte "se murio la maquina" en "murio ese test con
# exit 137", que es una senal accionable.
#
# Uso:
#   bash tools/guard-mem.sh node --test tests/foo.test.js
#
# Config (harness.config.sh o entorno):
#   HARNESS_MEM_MAX=2G    techo de RAM. "off" desactiva el guard por completo.
#
# Comportamiento:
#   - Con systemd de usuario y el controlador `memory` delegado: corre el comando
#     en un scope transitorio con MemoryMax y MemorySwapMax=0. Al pasarse, el
#     kernel mata SOLO ese cgroup; exit code 137.
#   - Sin eso (CI, contenedor, macOS, systemd ausente): corre el comando tal cual
#     y avisa por stderr. Nunca bloquea la ejecucion.
#
# Por que NO usamos `ulimit -v` como fallback: limita espacio de direcciones
# virtual, y V8 reserva rangos virtuales enormes que no son memoria real (el
# runaway de 10 GB de RSS tenia 27 GB de virtual). Un ulimit -v util para
# atajarlo haria fallar a node en arranque. MemoryMax mide RSS real.

set -u

[ "$#" -gt 0 ] || { echo "[guard-mem] falta el comando a ejecutar" >&2; exit 64; }

# Si el caller no cargo el entorno del arnes, cargarlo para leer HARNESS_MEM_MAX.
if [ -z "${HARNESS_MEM_MAX:-}" ]; then
  # shellcheck source=/dev/null
  . "$(dirname "${BASH_SOURCE[0]}")/harness-env.sh" 2>/dev/null || true
fi

LIMIT="${HARNESS_MEM_MAX:-2G}"
[ "$LIMIT" = "off" ] && exec "$@"

_uid="$(id -u)"
_controllers="/sys/fs/cgroup/user.slice/user-${_uid}.slice/user@${_uid}.service/cgroup.controllers"

if command -v systemd-run >/dev/null 2>&1 &&
   [ -r "$_controllers" ] &&
   grep -qw memory "$_controllers"; then
  # --collect: limpia el scope aunque el comando falle (si no, quedan units
  # en estado failed acumulandose).
  #
  # OOMPolicy=continue es la MISMA leccion que init.scope, un nivel mas abajo.
  # Un scope transitorio hereda el default OOMPolicy=stop: si el OOM killer del
  # cgroup mata UN proceso, systemd tira abajo el scope ENTERO. Para un runner
  # con workers (Stryker, jest, vitest) eso significa perder toda la corrida por
  # un solo caso patologico, cuando la herramienta ya sabe manejar un worker que
  # se muere: lo reporta y sigue. Visto en vivo el 2026-08-21: un mutante inflo
  # un worker a 2 GB, el cgroup lo mato bien (CONSTRAINT_MEMCG, sin tocar el
  # resto del sistema) y acto seguido systemd mato la corrida completa.
  exec systemd-run --user --scope -q --collect \
       -p MemoryMax="$LIMIT" -p MemorySwapMax=0 -p OOMPolicy=continue -- "$@"
fi

echo "[guard-mem] sin cgroup v2 delegado: corriendo SIN techo de memoria" >&2
exec "$@"
