#!/usr/bin/env python3
"""resolve-model.py — Resuelve fase → modelo desde model-map.yaml.

Fuente de verdad única para "qué modelo corre cada fase". Lo consumen
TANTO tools/run-opencode.sh (perfil opencode_go) como cualquier script que
necesite saber el modelo/canal de una fase.

Doble indirección: fase → tier (phase_tiers) → modelo (profiles.<perfil>.tiers).
Si existe phase_overrides[fase] y el perfil NO es anthropic, el override gana.

Uso:
  resolve-model.py <fase> [--field model|agent_model|tier|channel]
  resolve-model.py <fase>            # imprime el modelo (provider/model) o alias

Salida (por defecto, una línea): el modelo resuelto.
  --field tier         -> tier semántico (deep/standard/cheap)
  --field agent_model  -> agent_model crudo del tier
  --field channel      -> opencode | agent   (cómo invocarlo)
  --field all          -> "fase|perfil|tier|channel|modelo"

Canal:
  - spec_partner, design_partner, judge -> "agent"  (siempre Claude vía Agent(),
                                                     en ambos perfiles)
  - resto                -> "opencode" si active_profile==opencode_go, else "agent"
"""
import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write("PyYAML no instalado. Instala: pip install pyyaml\n")
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent
MAP = ROOT / "model-map.yaml"

# Fases que SIEMPRE corren en Claude Agent (no abaratar), ambos perfiles.
ALWAYS_AGENT = {"spec_partner", "design_partner", "judge"}


def load():
    if not MAP.exists():
        sys.stderr.write(f"No existe {MAP}\n")
        sys.exit(2)
    with MAP.open() as f:
        return yaml.safe_load(f)


def resolve(phase: str, data: dict):
    profile = data.get("active_profile")
    if profile not in (data.get("profiles") or {}):
        sys.stderr.write(f"active_profile '{profile}' no definido en profiles\n")
        sys.exit(2)

    tiers = data["phase_tiers"]
    if phase not in tiers:
        sys.stderr.write(f"Fase '{phase}' no está en phase_tiers\n")
        sys.exit(2)
    tier = tiers[phase]

    prof = data["profiles"][profile]
    tier_map = prof.get("tiers", {})
    if tier not in tier_map:
        sys.stderr.write(f"Tier '{tier}' no definido en perfil '{profile}'\n")
        sys.exit(2)

    channel = "agent" if phase in ALWAYS_AGENT else (
        "agent" if profile == "anthropic" else "opencode"
    )

    # Override (solo perfiles no-anthropic)
    model = tier_map[tier].get("agent_model") or tier_map[tier].get("model")
    overrides = data.get("phase_overrides") or {}
    override_used = False
    if profile != "anthropic" and phase in overrides:
        ov = overrides[phase]
        if "model" in ov and ov["model"]:
            model = ov["model"]
            override_used = True

    return {
        "phase": phase,
        "profile": profile,
        "tier": tier,
        "channel": channel,
        "model": model,
        "agent_model": tier_map[tier].get("agent_model"),
        "override": override_used,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("phase", help="nombre de la fase (spec_partner, gherkin_author, ...)")
    ap.add_argument("--field", default="model",
                    choices=["model", "agent_model", "tier", "channel", "all"])
    args = ap.parse_args()

    r = resolve(args.phase, load())
    if args.field == "all":
        src = "override" if r["override"] else "tier"
        print(f"{r['phase']}|{r['profile']}|{r['tier']}|{r['channel']}|{r['model']}|{src}")
    elif args.field == "agent_model":
        print(r["agent_model"])
    elif args.field == "tier":
        print(r["tier"])
    elif args.field == "channel":
        print(r["channel"])
    else:
        print(r["model"])


if __name__ == "__main__":
    main()
