#!/usr/bin/env python3
"""Mutador mínimo y sin dependencias para prueba de mutación.

Introduce un defecto pequeño en un archivo de código, corre la suite de
tests y comprueba si algún test falla (mutante MUERTO) o si todos pasan
(mutante SOBREVIVIENTE). Un sobreviviente es un agujero en la red de tests.

Uso:
    python3 tools/mutate.py src/cli.py
    python3 tools/mutate.py src/cli.py --max 80
    python3 tools/mutate.py src/cli.py --test-cmd "python3 -m pytest -q"

El comando de tests se resuelve, por orden de prioridad:
    1. --test-cmd "..."
    2. variable de entorno HARNESS_TEST_CMD (la pone harness.config.sh)
    3. valor por defecto: unittest discover sobre ./tests

Diseño (orientado a Python):
- Trabaja a nivel de *token* (módulo `tokenize`), así que NUNCA muta el
  contenido de strings ni comentarios: solo operadores, palabras clave,
  números y sentencias `return`.
- Descarta los mutantes que no compilan (no inflan la puntuación).
- Restaura SIEMPRE el archivo original, incluso ante Ctrl-C (bloque `finally`).

Para otros lenguajes, apunta HARNESS_MUTATION_CMD a la herramienta nativa
(Stryker, cargo-mutants, go-mutesting…). Ver docs/mutation-testing.md.
"""
from __future__ import annotations

import argparse
import io
import os
import shlex
import subprocess
import sys
import tokenize

# Mutaciones de operador: token OP -> reemplazo.
OP_MUTATIONS = {
    "<=": "<", ">=": ">", "<": "<=", ">": ">=",
    "==": "!=", "!=": "==", "+": "-", "-": "+",
}

# Mutaciones de palabra/constante: token NAME -> reemplazo.
NAME_MUTATIONS = {
    "and": "or", "or": "and", "True": "False", "False": "True",
}

DEFAULT_TEST_CMD = [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-q"]


def resolve_test_cmd(cli_value: str | None) -> list[str]:
    raw = cli_value or os.environ.get("HARNESS_TEST_CMD")
    if not raw or raw.strip().startswith("TODO"):
        return DEFAULT_TEST_CMD
    return shlex.split(raw)


class Mutant:
    """Una única mutación: reemplaza un span (línea, col) del fuente."""

    def __init__(self, row: int, col_start: int, col_end: int,
                 original: str, replacement: str, label: str):
        self.row = row              # 1-based
        self.col_start = col_start  # 0-based
        self.col_end = col_end
        self.original = original
        self.replacement = replacement
        self.label = label

    def apply(self, lines: list[str]) -> str:
        out = list(lines)
        line = out[self.row - 1]
        out[self.row - 1] = line[: self.col_start] + self.replacement + line[self.col_end:]
        return "".join(out)

    def describe(self, path: str) -> str:
        return f"{path}:{self.row}  {self.label}  ({self.original!r} -> {self.replacement!r})"


def _int_mutation(literal: str) -> str | None:
    """Mutación de un literal entero: n -> n+1 (y 0 -> 1, sin tocar floats)."""
    try:
        value = int(literal, 0)
    except ValueError:
        return None
    return str(value + 1)


def generate_mutants(source: str) -> list[Mutant]:
    mutants: list[Mutant] = []
    try:
        tokens = list(tokenize.generate_tokens(io.StringIO(source).readline))
    except tokenize.TokenError:
        return mutants

    for tok in tokens:
        if tok.start[0] != tok.end[0]:
            continue
        row = tok.start[0]
        col_start, col_end = tok.start[1], tok.end[1]
        text = tok.string

        if tok.type == tokenize.OP and text in OP_MUTATIONS:
            mutants.append(Mutant(row, col_start, col_end, text,
                                  OP_MUTATIONS[text], "operador"))
        elif tok.type == tokenize.NAME and text in NAME_MUTATIONS:
            mutants.append(Mutant(row, col_start, col_end, text,
                                  NAME_MUTATIONS[text], "palabra"))
        elif tok.type == tokenize.NUMBER:
            repl = _int_mutation(text)
            if repl is not None:
                mutants.append(Mutant(row, col_start, col_end, text,
                                      repl, "número"))

    # Mutación de retorno: `return <expr>` -> `return None`.
    lines = source.splitlines(keepends=True)
    for idx, raw in enumerate(lines, start=1):
        stripped = raw.lstrip()
        if not stripped.startswith("return "):
            continue
        rest = stripped[len("return "):].strip()
        if rest in ("", "None"):
            continue
        indent = len(raw) - len(stripped)
        content = raw.rstrip("\n")
        mutants.append(
            Mutant(idx, indent, len(content),
                   content[indent:], "return None", "retorno")
        )
    return mutants


def compiles(source: str, path: str) -> bool:
    try:
        compile(source, path, "exec")
        return True
    except SyntaxError:
        return False


def run_tests(test_cmd: list[str]) -> bool:
    """Devuelve True si la suite pasa (returncode 0)."""
    result = subprocess.run(test_cmd, stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL)
    return result.returncode == 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prueba de mutación mínima.")
    parser.add_argument("path", help="Archivo de código a mutar.")
    parser.add_argument("--max", type=int, default=100,
                        help="Máximo de mutantes a evaluar (default 100).")
    parser.add_argument("--test-cmd", default=None,
                        help="Comando de tests (default: $HARNESS_TEST_CMD o unittest).")
    args = parser.parse_args(argv)

    test_cmd = resolve_test_cmd(args.test_cmd)

    with open(args.path, "r", encoding="utf-8") as f:
        original = f.read()
    lines = original.splitlines(keepends=True)

    if not run_tests(test_cmd):
        print("[FAIL] La suite está roja sin mutar. Arregla los tests primero.",
              file=sys.stderr)
        return 2

    mutants = generate_mutants(original)
    valid = [m for m in mutants if compiles(m.apply(lines), args.path)]
    skipped_noncompile = len(mutants) - len(valid)

    truncated = 0
    if len(valid) > args.max:
        truncated = len(valid) - args.max
        valid = valid[: args.max]

    killed: list[Mutant] = []
    survived: list[Mutant] = []

    print(f"── Mutando {args.path} ─ {len(valid)} mutantes válidos "
          f"({skipped_noncompile} descartados por no compilar)")
    print(f"   test_cmd: {' '.join(test_cmd)}")
    try:
        for i, m in enumerate(valid, start=1):
            with open(args.path, "w", encoding="utf-8") as f:
                f.write(m.apply(lines))
            if run_tests(test_cmd):
                survived.append(m)
                mark = "SOBREVIVE"
            else:
                killed.append(m)
                mark = "muerto"
            print(f"  [{i}/{len(valid)}] {mark:9} {m.describe(args.path)}")
    finally:
        with open(args.path, "w", encoding="utf-8") as f:
            f.write(original)

    total = len(valid)
    score = (len(killed) / total * 100) if total else 100.0

    print("\n── Resumen ──────────────────────────────────────")
    print(f"  total:    {total}")
    print(f"  killed:   {len(killed)}")
    print(f"  survived: {len(survived)}")
    print(f"  score:    {score:.1f}%")
    if truncated:
        print(f"  [WARN] {truncated} mutantes válidos NO evaluados "
              f"(límite --max={args.max}). Sube --max para cobertura total.")
    if survived:
        print("\n  Mutantes sobrevivientes (agujeros en la red):")
        for m in survived:
            print(f"   - {m.describe(args.path)}")

    return 0 if not survived else 1


if __name__ == "__main__":
    sys.exit(main())
