#!/usr/bin/env bash
# tools/run-opencode.sh — Wrapper híbrido: invoca opencode run desde Claude Code.
#
# Uso: tools/run-opencode.sh <agent_name> [model] [prompt_file]
#
# El craftsman_lead (en Claude Code) usa este script para delegar una fase
# a opencode con un modelo Go. Captura la salida JSON y extrae el contrato
# de 4 campos (status/artifact/risks/next).
#
# Dependencias: opencode CLI instalado y configurado con Go subscription.
#               Ver: https://opencode.ai/docs/go

set -euo pipefail

AGENT="${1:?"Uso: run-opencode.sh <agent_name> [model] [prompt_file]"}"
MODEL="${2:-}"
PROMPT_FILE="${3:-}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Construir comando opencode
CMD=(opencode run --agent "$AGENT" --format json)

# Modelo override (opcional: si se omite, usa el definido en el agente)
if [ -n "$MODEL" ]; then
  CMD+=(--model "$MODEL")
fi

# Archivo de prompt (opcional)
if [ -n "$PROMPT_FILE" ]; then
  CMD+=(--file "$PROMPT_FILE")
fi

# Auto-aprobar permisos (el lead ya decidió que esta fase corra)
CMD+=(--dangerously-skip-permissions)

# Ejecutar y capturar
cd "$PROJECT_ROOT"
OUTPUT=$("${CMD[@]}" 2>/dev/null) || {
  echo "status: blocked" >&2
  echo "artifact: -" >&2
  echo "risks: opencode run falló para agente '$AGENT'" >&2
  echo "next: revisa que opencode esté configurado y la suscripción Go activa" >&2
  exit 1
}

# Extraer contrato de 4 campos de la salida JSON
# opencode --format json devuelve eventos; tomamos el último mensaje del asistente
STATUS=$(echo "$OUTPUT" | grep -o '"status":[^,}]*' | tail -1 | cut -d: -f2 | tr -d '" ')
ARTIFACT=$(echo "$OUTPUT" | grep -o '"artifact":[^,}]*' | tail -1 | cut -d: -f2 | tr -d '" ')
RISKS=$(echo "$OUTPUT" | grep -o '"risks":[^,}]*' | tail -1 | cut -d: -f2 | tr -d '" ')
NEXT=$(echo "$OUTPUT" | grep -o '"next":[^,}]*' | tail -1 | cut -d: -f2 | tr -d '" ')

# Fallback: si no encontró contrato, el agente no siguió el formato
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
