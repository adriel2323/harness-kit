#!/usr/bin/env python3
"""Mutador mínimo y sin dependencias para prueba de mutación.

Introduce un defecto pequeño en un archivo de código, corre la suite de
tests y comprueba si algún test falla (mutante MUERTO) o si todos pasan
(mutante SOBREVIVIENTE). Un sobreviviente es un agujero en la red de tests.

Uso:
    python3 tools/mutate.py src/cli.py
    python3 tools/mutate.py src/cli.py --max 80   # DEBUG: acota; si trunca, exit 3
    python3 tools/mutate.py src/cli.py --test-cmd "python3 -m pytest -q"
    python3 tools/mutate.py src/cli.py --progress-file progress/.mutation-live.log

Códigos de salida:
    0  todos los mutantes evaluados y todos muertos (gate verde).
    1  hay sobrevivientes (agujeros en la red de tests).
    2  la suite está roja SIN mutar (arreglá los tests primero).
    3  --max truncó la lista → evidencia parcial → gate rojo (aunque el score
       de lo evaluado diera 100%). Sin --max se evalúan TODOS (default).

--progress-file escribe una línea por mutante A MEDIDA que se evalúa (no al
final): quien corre esto en background (un subagente, un wrapper de
opencode) puede quedar sin ver el stdout hasta que el proceso termina, pero
este archivo se puede leer en cualquier momento sin interferir con la
corrida (es de solo lectura para quien lo mira).

El comando de tests se resuelve, por orden de prioridad:
    1. --test-cmd "..."
    2. variable de entorno HARNESS_TEST_CMD (la pone harness.config.sh)
    3. valor por defecto: unittest discover sobre ./tests

Diseño (orientado a Python):
- Trabaja a nivel de *token* (módulo `tokenize`), así que NUNCA muta el
  contenido de strings ni comentarios: solo operadores, palabras clave,
  números y sentencias `return`.
- Descarta los mutantes que no compilan (no inflan la puntuación).
- Restaura SIEMPRE el archivo original, incluso ante Ctrl-C o SIGTERM (bloque
  `finally`, ver el handler de SIGTERM más abajo). Un SIGKILL sigue sin poder
  atraparse (limitación del SO, no de este script) — si eso pasa, el archivo
  puede quedar con un mutante pegado; revisalo antes de asumir que el código
  está roto de verdad.

Para otros lenguajes, apunta HARNESS_MUTATION_CMD a la herramienta nativa
(Stryker, cargo-mutants, go-mutesting…). Ver docs/mutation-testing.md.
"""
from __future__ import annotations

import argparse
import io
import os
import shlex
import signal
import subprocess
import sys
import tokenize

signal.signal(signal.SIGTERM, signal.default_int_handler)

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


# Segundos que se le dan a la suite por mutante antes de considerarla colgada.
# Ver _resolve_timeout() y la cabecera de este modulo.
DEFAULT_TIMEOUT = 120

# Proceso de tests en curso. Global porque hay que poder matarlo desde el
# `finally` de main() y desde el handler de senales, no solo desde run_tests().
_ACTIVE: subprocess.Popen | None = None


def _resolve_timeout(cli_value: int | None) -> int | None:
    """Segundos por corrida de tests. None = sin limite (peligroso, ver abajo)."""
    if cli_value is None:
        raw = os.environ.get("HARNESS_MUTATION_TIMEOUT", "").strip()
        try:
            cli_value = int(raw) if raw else DEFAULT_TIMEOUT
        except ValueError:
            cli_value = DEFAULT_TIMEOUT
    return None if cli_value <= 0 else cli_value


def _kill_active() -> None:
    """Mata la corrida de tests en curso y TODA su descendencia.

    Matar solo al hijo directo no alcanza: si HARNESS_TEST_CMD es un wrapper
    (`bash tools/test-node.sh`), morir el bash deja al `node` nieto huerfano y
    corriendo. Por eso los lanzamos con start_new_session=True (grupo propio) y
    aca senalizamos al GRUPO ENTERO con killpg.
    """
    global _ACTIVE
    proc = _ACTIVE
    _ACTIVE = None
    if proc is None or proc.poll() is not None:
        return
    try:
        pgid = os.getpgid(proc.pid)
    except OSError:
        pgid = None
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            if pgid is not None:
                os.killpg(pgid, sig)
            else:
                proc.send_signal(sig)
        except OSError:
            return
        try:
            proc.wait(timeout=5)
            return
        except subprocess.TimeoutExpired:
            continue


def run_tests(test_cmd: list[str],
              timeout: int | None = DEFAULT_TIMEOUT) -> tuple[bool, bool]:
    """Corre la suite. Devuelve (paso, se_colgo).

    `paso` es True solo si el proceso termino con returncode 0.

    POR QUE HAY TIMEOUT (2026-08-21): antes esto era un subprocess.run() sin
    limite. Un mutante que introduce un bucle infinito (o que deja un handle de
    BD abierto sin --test-force-exit) cuelga la corrida para siempre y el
    proceso crece sin techo. Paso de verdad: un `node --test` huerfano llego a
    10.1 GB de RSS, agoto 16 GB de swap y el OOM killer se llevo puesta la
    distro WSL entera.

    Un timeout cuenta como MUTANTE MUERTO, y esta bien que asi sea: la suite no
    paso, que es exactamente lo que se le pide detectar. Se marca aparte en el
    log ("muerto(timeout)") porque un timeout casi siempre significa que el
    mutante genero un bucle infinito, no que el test hizo una asercion.
    """
    global _ACTIVE
    proc = subprocess.Popen(test_cmd, stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            start_new_session=True)
    _ACTIVE = proc
    try:
        return proc.wait(timeout=timeout) == 0, False
    except subprocess.TimeoutExpired:
        _kill_active()
        return False, True
    finally:
        _ACTIVE = None


def _log(progress_file: str | None, line: str) -> None:
    """Escribe una línea al archivo de progreso (si se pidió uno) y la
    flushea de inmediato abriendo/cerrando en cada llamada: así un lector
    externo (Read, tail) siempre ve el estado real, sin buffers de por medio."""
    if not progress_file:
        return
    with open(progress_file, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prueba de mutación mínima.")
    parser.add_argument("path", help="Archivo de código a mutar.")
    parser.add_argument("--max", type=int, default=None,
                        help="Tope de mutantes a evaluar (DEBUG). Default: sin "
                             "tope, se evalúan TODOS. Si un --max explícito deja "
                             "mutantes sin evaluar, el gate sale ROJO (exit 3): "
                             "el score sobre evidencia parcial no vale.")
    parser.add_argument("--test-cmd", default=None,
                        help="Comando de tests (default: $HARNESS_TEST_CMD o unittest).")
    parser.add_argument("--progress-file", default=None,
                        help="Ruta donde ir logueando cada mutante a medida que se evalúa.")
    parser.add_argument("--timeout", type=int, default=None,
                        help=f"Segundos por corrida de tests antes de dar el "
                             f"mutante por colgado (default: "
                             f"$HARNESS_MUTATION_TIMEOUT o {DEFAULT_TIMEOUT}). "
                             f"0 o negativo = sin limite: NO lo uses, un mutante "
                             f"con bucle infinito puede tumbar la maquina.")
    args = parser.parse_args(argv)

    test_cmd = resolve_test_cmd(args.test_cmd)
    timeout = _resolve_timeout(args.timeout)
    if args.progress_file:
        with open(args.progress_file, "w", encoding="utf-8") as f:
            f.write(f"── arrancando mutación de {args.path} ──\n")

    with open(args.path, "r", encoding="utf-8") as f:
        original = f.read()
    lines = original.splitlines(keepends=True)

    baseline_ok, baseline_hung = run_tests(test_cmd, timeout)
    if not baseline_ok:
        if baseline_hung:
            print(f"[FAIL] La suite SIN MUTAR se colgó (>{timeout}s). No es un "
                  f"mutante: revisá handles abiertos (¿falta --test-force-exit?) "
                  f"o subí --timeout si de verdad tarda tanto.", file=sys.stderr)
        else:
            print("[FAIL] La suite está roja sin mutar. Arregla los tests primero.",
                  file=sys.stderr)
        return 2

    mutants = generate_mutants(original)
    valid = [m for m in mutants if compiles(m.apply(lines), args.path)]
    skipped_noncompile = len(mutants) - len(valid)

    # Sin --max se evalúan TODOS los mutantes válidos (default None). Un --max
    # explícito es solo herramienta de debug: si trunca, deja evidencia parcial
    # y el gate sale rojo (exit 3) más abajo. total_valid guarda el universo
    # real (Y en "evaluados X de Y").
    total_valid = len(valid)
    truncated = 0
    if args.max is not None and len(valid) > args.max:
        truncated = len(valid) - args.max
        valid = valid[: args.max]

    killed: list[Mutant] = []
    survived: list[Mutant] = []

    header = (f"── Mutando {args.path} ─ {len(valid)} mutantes válidos "
              f"({skipped_noncompile} descartados por no compilar)")
    print(header)
    print(f"   test_cmd: {' '.join(test_cmd)}")
    _log(args.progress_file, header)
    _log(args.progress_file, f"   test_cmd: {' '.join(test_cmd)}")
    _log(args.progress_file,
         f"   timeout:  {timeout}s por mutante" if timeout
         else "   timeout:  SIN LIMITE (riesgo de colgar la maquina)")
    try:
        for i, m in enumerate(valid, start=1):
            with open(args.path, "w", encoding="utf-8") as f:
                f.write(m.apply(lines))
            passed, hung = run_tests(test_cmd, timeout)
            if passed:
                survived.append(m)
                mark = "SOBREVIVE"
            else:
                killed.append(m)
                mark = "muerto(timeout)" if hung else "muerto"
            line = f"  [{i}/{len(valid)}] {mark:15} {m.describe(args.path)}"
            print(line)
            _log(args.progress_file, line)
    finally:
        # Primero matar los tests, DESPUES restaurar: si restauramos con la
        # corrida viva, el proceso puede seguir leyendo el archivo a medias.
        # Esto cubre Ctrl-C y SIGTERM (el handler de arriba los convierte en
        # KeyboardInterrupt, que pasa por este finally), que es justo el caso en
        # que antes quedaban procesos huerfanos comiendo memoria.
        _kill_active()
        with open(args.path, "w", encoding="utf-8") as f:
            f.write(original)
        _log(args.progress_file, "── archivo original restaurado ──")

    total = len(valid)
    score = (len(killed) / total * 100) if total else 100.0

    print("\n── Resumen ──────────────────────────────────────")
    print(f"  total:    {total}")
    print(f"  killed:   {len(killed)}")
    print(f"  survived: {len(survived)}")
    print(f"  score:    {score:.1f}%")
    _log(args.progress_file, f"── Resumen: total={total} killed={len(killed)} "
                              f"survived={len(survived)} score={score:.1f}% ──")
    if truncated:
        # Evidencia parcial: se evaluaron X de Y mutantes válidos. El score de
        # arriba solo cubre lo medido; los no evaluados quedan sin veredicto.
        # Esto NO es un warning cosmético: es gate rojo (exit 3), porque un
        # gate que se satisface con parte del universo miente.
        evaluados = f"evaluados {total} de {total_valid}"
        msg = (f"  [FAIL] {truncated} mutantes válidos SIN evaluar por "
               f"--max={args.max} ({evaluados}). Evidencia incompleta: el gate "
               f"exige cobertura total (corré sin --max).")
        print(msg)
        _log(args.progress_file, f"── {evaluados} (truncado por --max={args.max}) "
                                  f"→ gate rojo (exit 3) ──")
    if survived:
        print("\n  Mutantes sobrevivientes (agujeros en la red):")
        for m in survived:
            print(f"   - {m.describe(args.path)}")

    # Precedencia de exit: truncado (evidencia parcial) manda sobre todo, aunque
    # además haya sobrevivientes (que igual se reportan arriba).
    if truncated:
        return 3
    return 0 if not survived else 1


if __name__ == "__main__":
    sys.exit(main())
