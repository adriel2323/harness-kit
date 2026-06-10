# QUICKSTART — Arrancar el arnés en un repo existente

Guía mínima de principio a fin: descargar el kit, instalarlo en tu proyecto
y empezar a producir specs. Para el detalle del flujo, ver `docs/workflow.md`
(y `INSTALL.md` en el kit, para la adaptación por lenguaje).

## 0. Punto de partida

Tu proyecto ya existe y tiene git. Trabaja sobre un árbol limpio o una rama:

```bash
cd /ruta/a/tu/proyecto
git status        # working tree limpio o en una rama de trabajo
```

## 1. Conseguir el kit del arnés

El kit es la carpeta `craftsman-harness-kit/`. **No va dentro** de tu proyecto:
vive aparte y su `install.sh` copia lo necesario a la raíz de tu repo.

```bash
# Opción A — clonarlo desde tu remoto del arnés:
git clone <url-del-repo-harness> /tmp/harness
#   el kit queda en /tmp/harness/craftsman-harness-kit

# Opción B — ya lo tienes en local: usa esa ruta directamente.
```

## 2. Instalar en tu proyecto

Desde la carpeta del kit, apunta a la raíz de tu proyecto:

```bash
cd /ruta/al/craftsman-harness-kit
./install.sh /ruta/a/tu/proyecto
```

Esto: copia el arnés (sin pisar lo tuyo), detecta el lenguaje y escribe
`harness.config.sh`, y lo deja **local-only** (añade un bloque a tu
`.gitignore` para que tu repo no versione el arnés).

```bash
cd /ruta/a/tu/proyecto
git status        # el arnés NO debe aparecer (es local-only)
```

> ¿Tu equipo quiere versionar el arnés con el proyecto? Instala con
> `./install.sh /ruta/a/tu/proyecto --share-harness`.

## 3. Ajustar la config y verificar

```bash
cat harness.config.sh     # ¿el comando de tests es el tuyo?
./init.sh                 # debe terminar verde: [OK] Entorno listo
```

Si `./init.sh` falla por el toolchain o el comando de tests, corrige la línea
correspondiente en `harness.config.sh` y vuelve a correrlo.

## 4. Bootstrap (una vez) en Claude Code

Abre Claude Code en la raíz del proyecto y pide:

> **«Haz el bootstrap del arnés para este proyecto.»**

El agente `harness_bootstrap` confirma lenguaje/comandos, rellena
`docs/architecture.md` y `docs/conventions.md` con las reglas **reales** de tu
repo (describe lo que ya tienes, no inventa) y, si se lo pides, siembra
`feature_list.json`.

## 5. Definir la primera feature

En `feature_list.json`, una entrada `pending` con `"sdd": true`:

```json
{
  "id": 1,
  "name": "mi_feature",
  "title": "...",
  "description": "...",
  "acceptance": ["criterio observable 1", "caso de error 1"],
  "sdd": true,
  "status": "pending"
}
```

## 6. Arrancar el flujo de specs

En Claude Code pide:

> **«implementa la siguiente feature pendiente»**

Lo que ocurre (y dónde paras):

1. `spec_partner` **debate** contigo → `project-spec.md`.
2. `gherkin_author` destila `features/mi_feature.feature` → estado `spec_ready`.
3. **⏸ PUERTA HUMANA** — el flujo se detiene. Lees los escenarios y respondes
   **«aprobado»** (o pides cambios).
4. Tras tu OK: `tdd_craftsman` (Rojo→Verde→Refactor) → `judge` (review) →
   `mutation_tester`. Solo si la mutación supera el umbral, la feature pasa a
   `done`.

---

## Resumen de comandos

```bash
# 1-2: instalar
cd /ruta/al/craftsman-harness-kit
./install.sh /ruta/a/tu/proyecto

# 3: verificar
cd /ruta/a/tu/proyecto
./init.sh

# 4-6: en Claude Code
#   «Haz el bootstrap del arnés para este proyecto.»
#   (editas feature_list.json con tu primera feature: pending + sdd:true)
#   «implementa la siguiente feature pendiente»
```
