# Craftsman Harness Kit

> Un arnés de trabajo agente, **agnóstico al lenguaje**, para llevar
> cualquier proyecto (nuevo o ya en producción) por el flujo de Robert C.
> Martin (Uncle Bob): **conversar la spec → destilarla en Gherkin → tallar
> con TDD estricto → podar con juicio → validar con prueba de mutación**,
> siempre con una **puerta de aprobación humana** en el punto de máximo
> apalancamiento.

Este kit es la **plantilla portable** extraída del ejemplo `notes-cli` en
Python. No trae código de aplicación: trae el **proceso**, los **agentes**,
los **documentos de disciplina** y los **arneses de verificación**, listos
para instalarse en la raíz de tu proyecto y empezar a trabajar así desde el
minuto cero.

---

## Qué resuelve

La IA teclea infinito; lo escaso es el **juicio** y la **verificación**.
Este arnés convierte ese principio en estructura:

| Riesgo de trabajar con IA "a pelo"        | Cómo lo ataja el arnés                              |
|-------------------------------------------|-----------------------------------------------------|
| El modelo "entiende" mal el requisito     | Spec **conversada y debatida** (`spec_partner`)     |
| Ambigüedad que explota tarde, en el código| **Gherkin** como contrato firmado antes de codear   |
| Código que nadie pidió (alcance inflado)  | **TDD estricto**, un test a la vez (`tdd_craftsman`)|
| "Funciona en mi máquina" sin pruebas      | **Review** que poda (`judge`) + `init.sh` verde     |
| Tests verdes que no prueban nada          | **Prueba de mutación** (`mutation_tester`)          |
| Estado perdido entre sesiones             | Todo vive **en disco** (`progress/`, `features/`)   |
| La IA decide sola lo irreversible         | **Puerta humana** sobre el contrato Gherkin         |

## El pipeline

```
pending
  → [spec_partner]    CONVERSACIÓN  → project-spec.md
  → [gherkin_author]  DESTILACIÓN   → features/<name>.feature   (spec_ready)
  → ⏸  PUERTA HUMANA: el humano aprueba los escenarios (el contrato)
  → in_progress
  → [tdd_craftsman]   ROJO → VERDE → REFACTOR  → código + tests
  → [judge]           REVIEW ("el review es el juego entero")
  → [mutation_tester] MUTACIÓN (valida que los tests muerden)
  → done
```

Una sola feature a la vez. Una sola puerta de aprobación humana: sobre el
contrato Gherkin, **antes** de escribir producción.

## Agnóstico al lenguaje

El proceso es universal; los **comandos** no. Todo lo específico del lenguaje
(cómo se corren los tests, la mutación, el build) vive en **un solo archivo**:
`harness.config.sh`. El resto del arnés lo lee de ahí.

- Trae **perfiles listos** en `profiles/` para `python`, `node`, `go` y
  `rust`, más un `generic` para cualquier otro stack.
- El instalador **detecta** el lenguaje del proyecto y rellena la config.
- El agente `harness_bootstrap` confirma la detección y personaliza
  `docs/architecture.md` y `docs/conventions.md` para tu stack **antes** de
  arrancar el flujo.

## Instalación rápida

Desde la carpeta del kit, instálalo en la raíz de tu proyecto:

```bash
./install.sh /ruta/a/tu/proyecto
```

El instalador:

1. Instala con **layout consolidado**: la maquinaria va a `harness-kit/` y solo
   `.claude/` (con un `CLAUDE.md` puntero) queda en la raíz. No pisa archivos
   existentes salvo que pases `--force`.
2. Detecta el lenguaje y escribe `harness.config.sh` desde el perfil adecuado.
3. **Lo deja local-only**: añade un bloque gestionado al `.gitignore` del
   proyecto para que su repo no versione el arnés (es parte de tu ecosistema
   de desarrollo, no del proyecto). Usa `--share-harness` para versionarlo.
4. Te deja `init.sh` ejecutable y te dice el siguiente paso.

Luego, en la raíz del proyecto:

```bash
./init.sh            # debe terminar verde
```

Y abre Claude Code y pide: **«implementa la siguiente feature pendiente»**.

> ¿Lenguaje no detectado o stack raro? El instalador copia el perfil
> `generic` con marcadores `TODO:`; el agente `harness_bootstrap` (o tú) los
> rellena. Ver [`INSTALL.md`](INSTALL.md).

## Actualizar y migrar instalaciones

El arnés evoluciona; estos comandos propagan los cambios a los proyectos donde
ya lo instalaste, **sin pisar tu trabajo**:

```bash
./install.sh /ruta/al/proyecto --update   # refresca la maquinaria, preserva tu estado
./update-all.sh                            # actualiza TODOS los proyectos registrados
./update-all.sh --list                     # lista instalaciones y su versión
./update-all.sh --dry-run                  # muestra qué actualizaría, sin tocar
./update-all.sh --prune                    # quita del registro rutas que ya no existen
```

- **`--update`** reemplaza la maquinaria (docs/, tools/, agentes, skills,
  `init.sh`, `settings.json`…) a la última versión, pero **preserva tu estado**:
  `feature_list.json`, `project-spec.md`, `progress/`, `features/` y
  `harness.config.sh`. Hace backup de `settings.json` antes de regenerarlo.
- Cada instalación queda anotada en un **registro local** (`.harness-installs`,
  ignorado por git) con su ruta y versión; `update-all.sh` lo recorre para
  actualizarlas todas con un comando.
- **`--migrate`** convierte una instalación **vieja de layout plano** (con el
  arnés disperso en la raíz del proyecto) al layout consolidado: hace un backup
  `.tgz`, mueve tu estado a `harness-kit/`, parcha `harness.config.sh`
  (`HARNESS_PROJECT_ROOT` + campos del test individual) y limpia la raíz,
  preservando tus docs propios y `.claude/settings.local.json`.

## Qué incluye

```
craftsman-harness-kit/
├── README.md                  # este archivo
├── INSTALL.md                 # guía de instalación y adaptación por lenguaje
├── install.sh                 # instalador: copia/--update/--migrate + detecta lenguaje
├── update-all.sh              # actualiza todos los proyectos registrados (--list/--prune)
├── harness.config.sh          # ⚙️  config central (comandos por lenguaje)
├── init.sh                    # verificación: lee la config, no asume lenguaje
├── .gitignore                 # solo para el repo DEL KIT (no se instala);
│                              #   en el proyecto, install.sh gestiona el suyo
├── CLAUDE.md                  # fuerza el rol craftsman_lead (agnóstico)
├── AGENTS.md                  # mapa de navegación para agentes
├── CHECKPOINTS.md             # criterios objetivos de "estado final correcto"
├── feature_list.json          # alcance: una feature a la vez (plantilla)
├── project-spec.md            # spec conversada (plantilla)
├── .claude/
│   ├── settings.json          # hooks + permisos (deny rules de costo/seguridad)
│   ├── agents/                # craftsman_lead, spec_partner, gherkin_author,
│   │                          #   tdd_craftsman, judge, mutation_tester,
│   │                          #   harness_bootstrap
│   └── skills/                # transversales: commit-hygiene, branch-pr, progress-log
├── docs/
│   ├── workflow.md            # el pipeline y los insights de cada fase
│   ├── tdd.md                 # las Tres Leyes del TDD; Rojo-Verde-Refactor
│   ├── gherkin.md             # cómo escribir .feature; de Gherkin a test
│   ├── mutation-testing.md    # por qué/cómo; umbral; tabla de tools por lenguaje
│   ├── architecture.md        # plantilla: "qué es buen trabajo" (rellena bootstrap)
│   ├── conventions.md         # plantilla: estilo/nombres (rellena bootstrap)
│   └── verification.md        # cómo demostrar que el trabajo funciona
├── tools/
│   ├── harness-env.sh         # resuelve KIT_DIR/PROJECT_ROOT y carga la config
│   ├── run-tests.sh           # wrapper agnóstico: suite (--one <file> para un test)
│   ├── test-affected.sh       # hook: corre solo el test del archivo editado
│   ├── run-mutation.sh        # wrapper: corre la mutación desde la raíz del proyecto
│   └── mutate.py              # mutador sin dependencias (Python; fallback genérico)
├── profiles/
│   ├── python.sh  node.sh  go.sh  rust.sh  generic.sh
└── progress/
    ├── current.md             # sesión activa (plantilla)
    └── history.md             # bitácora append-only (plantilla)
```

## Las ideas del hilo, mapeadas

| Paso          | Idea                                                                | Dónde vive               |
|---------------|---------------------------------------------------------------------|--------------------------|
| Spec conversada | «Hago que la IA escriba la spec a través de una conversación… debatimos» | `spec_partner`      |
| Gherkin       | «crear un conjunto de archivos .feature a partir del project-spec.md» | `gherkin_author`        |
| TDD           | «un solo test seguido del código (TDD)» — un test a la vez          | `tdd_craftsman`, `docs/tdd.md` |
| Review        | «El paso de review es el juego entero. Los agentes redactan, el juicio poda.» | `judge`        |
| Mutación      | «La prueba de mutación consume muchos recursos, pero el ROI… vale la pena.» | `mutation_tester`  |
| Cómputo como límite | «El poder de cómputo bruto es el factor limitante» — validar, no teclear | la mutación reejecuta la suite |

Detalle completo en [`docs/workflow.md`](docs/workflow.md).
