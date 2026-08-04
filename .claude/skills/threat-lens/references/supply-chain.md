# Perfil `supply` — dependencias, secretos, CI/CD y contenedores

> **Siempre activo**: todo repo tiene dependencias y secretos que puede filtrar.
>
> Este perfil es casi todo Cubeta B: se verifica por inspección del diff, no
> por escenario. Su lugar natural es el modo `review` del `judge`. La
> excepción son las features que *gestionan* configuración o secretos, donde
> sí hay comportamiento observable que exigir.

## Prioridad 1 — Secretos (bloqueante siempre, sin discusión)

Un secreto en el diff es un **BLOQUEANTE** aunque no esté commiteado todavía:
una vez en git, está comprometido — `git reset --hard` no lo borra del
historial, y lo que corresponde es **rotarlo**, no "limpiarlo".

```bash
grep -rnE "(api[_-]?key|secret|token|passwd|password|private[_-]?key)\s*[:=]\s*['\"][^'\"]{12,}" <archivos_del_diff>
grep -rnE "AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----" <archivos_del_diff>
git check-ignore -v .env 2>/dev/null || echo "BLOQUEANTE: .env no está en .gitignore"
```

También bloqueante: `.env.example` con valores reales en vez de placeholders,
y un secreto impreso en un log o en la salida de un script.

Escenario `@sec` cuando la feature **maneja** configuración:

```gherkin
  @s4 @sec
  Scenario: Abuso: se pide volcar la configuración cargada
    Given la configuración cargada con la clave de API "sk-valor-real"
    When se imprime el resumen de configuración
    Then la salida muestra "API_KEY=***"
    And la salida no contiene "sk-valor-real"
```

## Prioridad 2 — Dependencias

| Control | Cubeta | Qué exigir |
|---|---|---|
| Lockfile presente y commiteado | B | `package-lock.json` / `poetry.lock` / `go.sum` / `Cargo.lock` en el repo |
| Dependencia nueva justificada | B | toda dep añadida en el diff aparece como **decisión** en `project-spec.md` (ya lo pide C3 de `CHECKPOINTS.md`); `ponytail` rung 5 primero |
| Sin CVEs high/critical | B | `npm audit --audit-level=high` · `pip-audit` · `cargo audit` · `govulncheck` |
| Paquete real y no typosquat | B | verificar que el nombre existe y es el esperado — la IA inventa nombres de librerías |
| Scope interno protegido | B | paquetes internos con scope `@empresa/`, registry interno con prioridad |

Cuando el diff añade una dependencia, correr el audit del stack es parte del
modo `review`. Si el comando no está disponible, dilo — no lo des por pasado.

## Prioridad 3 — CI/CD

| Control | Cubeta | Qué exigir |
|---|---|---|
| Acciones de terceros fijadas a SHA | B | `uses: org/action@<sha40>`, no `@v4` |
| Sin secretos en logs de build | B | grep de `echo $SECRET`, `set -x` alrededor de credenciales |
| `persist-credentials: false` en checkout | B | evita exponer el token del runner |
| Instalación reproducible | B | `npm ci` (no `npm install`), `pip install -r` con hashes o lock |
| Gates de seguridad en el pipeline | C | SAST/SCA/secret scanning — se recomienda, no se verifica desde aquí |

## Prioridad 4 — Contenedores

| Control | Cubeta | Qué exigir |
|---|---|---|
| No corre como root | B | `USER` no-root en el `Dockerfile`; `runAsNonRoot: true` en K8s |
| Imagen base fijada y mínima | B | sin `:latest`; alpine/distroless o digest fijo |
| Sin secretos en capas | B | nada de `ENV API_KEY=…` ni `COPY .env` |
| Filesystem de solo lectura | B | `readOnlyRootFilesystem` donde aplique |

```bash
grep -nE "^FROM .*:latest|^USER root|^ENV .*(KEY|SECRET|TOKEN|PASSWORD)=|^COPY \.env" Dockerfile
```

## Formato de hallazgo

Este perfil produce sobre todo líneas de inspección. Sé citable:

```
BLOQUEANTE config/settings.py:12 — clave de API literal. Mover a variable de entorno y ROTAR la clave.
OBSERVACIÓN package.json:31 — dependencia nueva `left-pad` sin decisión en project-spec.md. ¿Stdlib no alcanza?
```

## Cubeta C — nómbralo y déjalo fuera

SBOM, firma de imágenes (cosign/Sigstore), SLSA, aislamiento de runners
self-hosted, branch protection, commits firmados, Dependabot/Renovate,
escaneo de imágenes en registry, admission controllers.
