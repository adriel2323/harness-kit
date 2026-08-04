#!/usr/bin/env bash
# tools/run-opencode.sh — Wrapper híbrido: invoca opencode run desde Claude Code.
#
# Uso: tools/run-opencode.sh <agent_name> <prompt_file|-> [model]
#
# El craftsman_lead (en Claude Code) usa este script para delegar una fase
# a opencode con un modelo Go. El modelo se resuelve desde model-map.yaml
# (fuente de verdad única) vía tools/resolve-model.py, salvo que se pase
# explícitamente como 3er argumento (caso de degradación).
#
# El prompt es OBLIGATORIO: es el mensaje que recibe el agente (la tarea de
# la fase). Se pasa como mensaje positional Y se adjunta con -f para que el
# agente vea el contexto completo. "-" lee de stdin.
#
# Salida (stdout): el contrato de 4 campos (status/artifact/risks/next) que
# el gatekeeper del craftsman_lead valida igual que a Agent(). SIEMPRE a stdout.
# Salida (stderr): traza A/B "fase → modelo resuelto (override|tier)" y
# errores reales de opencode (no se enmascaran).
#
# Dependencias: opencode CLI (>=1.17) con suscripción Go; python3 + PyYAML.

set -euo pipefail

AGENT="${1:?Uso: run-opencode.sh <agent_name> <prompt_file|-> [model]}"
PROMPT_FILE="${2:?Uso: run-opencode.sh <agent_name> <prompt_file|-> [model] (falta el prompt de la tarea)}"
MODEL_OVERRIDE="${3:-}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"

# emit_blocked <risks> <next>: contrato de fallo SIEMPRE a stdout.
emit_blocked() {
  echo "status: blocked"
  echo "artifact: -"
  echo "risks: $1"
  echo "next: $2"
}

# 1. Resolver modelo desde model-map.yaml (salvo override explícito = degradación).
if [ -n "$MODEL_OVERRIDE" ]; then
  MODEL="$MODEL_OVERRIDE"
  SRC="degrade"
else
  if ! MODEL="$(python3 "$HERE/resolve-model.py" "$AGENT" --field model 2>&1)"; then
    emit_blocked "resolve-model.py falló para fase '$AGENT': $MODEL" \
      "revisa model-map.yaml (active_profile y phase_tiers)"
    exit 1
  fi
  CHANNEL="$(python3 "$HERE/resolve-model.py" "$AGENT" --field channel)"
  if [ "$CHANNEL" != "opencode" ]; then
    AGENT_MODEL="$(python3 "$HERE/resolve-model.py" "$AGENT" --field model)"
    emit_blocked "la fase '$AGENT' tiene canal '$CHANNEL' (no opencode); va por Agent() en Claude" \
      "usa Agent(model=\"$AGENT_MODEL\") en vez de este wrapper"
    exit 1
  fi
  SRC="$(python3 "$HERE/resolve-model.py" "$AGENT" --field all | cut -d'|' -f6)"
fi

# Traza A/B para docs/model-fit.md §5/§7.
echo "[run-opencode] $AGENT → $MODEL ($SRC)" >&2

# 2. Leer el prompt (tarea de la fase). "-" = stdin.
if [ "$PROMPT_FILE" = "-" ]; then
  PROMPT="$(cat)"
else
  if [ ! -f "$PROMPT_FILE" ]; then
    emit_blocked "prompt_file '$PROMPT_FILE' no existe" \
      "escribe el prompt de la fase en disco (regla anti-teléfono-descompuesto)"
    exit 1
  fi
  PROMPT="$(cat "$PROMPT_FILE")"
fi

if [ -z "$PROMPT" ]; then
  emit_blocked "prompt vacío; el agente no tiene tarea" \
      "describe la tarea de la fase en el prompt_file"
  exit 1
fi

# 3. Construir comando opencode.
#    --auto aprueba permisos (el lead ya decidió que esta fase corra).
#    El flag --dangerously-skip-permissions NO existe en opencode >=1.17.
#
#    NOTA sobre opencode 1.17: el mensaje va como argumento positional.
#    Un mensaje multiline (con \n) se interpreta como ruta → "File not found".
#    Por eso aplanamos newlines a espacios. NO usamos -f: cuando -f está
#    presente, opencode trata TAMBIÉN el positional como ruta (mismo error).
CMD=(opencode run --agent "$AGENT" --model "$MODEL" --auto --format json)

# Aplanar newlines/tabs a espacios (preserva el contenido del prompt en una línea).
MESSAGE="$(printf '%s' "$PROMPT" | tr '\n\t' '  ' | tr -s ' ')"
MESSAGE="Ejecuta la fase $AGENT con el siguiente prompt. Devuelve SOLO el bloque de 4 campos (status/artifact/risks/next). PROMPT: $MESSAGE"

# 4. Ejecutar. stderr de opencode se conserva (separada del JSON) para diagnostico.
cd "$PROJECT_ROOT"
OUTPUT_FILE="$(mktemp)"
OP_ERR_FILE="$(mktemp)"
trap 'rm -f "$OUTPUT_FILE" "$OP_ERR_FILE"' EXIT

if ! "${CMD[@]}" "$MESSAGE" >"$OUTPUT_FILE" 2>"$OP_ERR_FILE"; then
  ERR_SUMMARY="$(head -3 "$OP_ERR_FILE" | tr '\n' ' ' | cut -c1-300)"
  emit_blocked "opencode run falló para agente '$AGENT': ${ERR_SUMMARY:-sin detalle}" \
    "revisa opencode config, suscripción Go, y que '$MODEL' exista (opencode models)"
  exit 1
fi

OUTPUT="$(cat "$OUTPUT_FILE")"

# 5. Extraer contrato de 4 campos del texto del último mensaje del asistente.
#    opencode --format json emite NDJSON de eventos; el contrato vive como TEXTO
#    dentro del mensaje (bloque "status: …/artifact: …/risks: …/next: …"), NO
#    como claves JSON. Tomamos la última ocurrencia de cada campo (el agente
#    puede citar la plantilla y luego su versión rellenada).
#
# Cadena de parseo: jq (ideal) → python3 (fallback robusto) → sed (último recurso).
if command -v jq >/dev/null 2>&1; then
  TEXT=$(echo "$OUTPUT" | jq -r '.. | strings' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  TEXT=$(echo "$OUTPUT" | python3 -c '
import json, sys
out = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    def walk(o):
        if isinstance(o, str):
            out.append(o)
        elif isinstance(o, dict):
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(obj)
print("\n".join(out))
' 2>/dev/null || true)
else
  TEXT=$(echo "$OUTPUT" | sed 's/\\"/"/g; s/\\n/\n/g')
fi

extract_field() {  # field_name
  echo "$TEXT" | grep -iE "^[[:space:]]*$1:" | tail -1 | sed -E "s/^[^:]*:[[:space:]]*//" | tr -d '\r' || true
}
STATUS=$(extract_field status)
ARTIFACT=$(extract_field artifact)
RISKS=$(extract_field risks)
NEXT=$(extract_field next)

# Fallback: si no encontró contrato, el agente no siguió el formato.
if [ -z "$STATUS" ]; then
  echo "status: partial"
  echo "artifact: -"
  echo "risks: el agente '$AGENT' no devolvió contrato de 4 campos"
  echo "next: -"
  exit 0
fi

echo "status: $STATUS"
echo "artifact: $ARTIFACT"
echo "risks: $RISKS"
echo "next: $NEXT"
