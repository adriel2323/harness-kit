# Perfil `datos` — DBA, pipelines y analítica

> Cargar si la feature toca SQL, migraciones, multi-tenancy, exports,
> notebooks o pipelines ETL/ELT.
>
> Buena parte de este perfil vive en Cubeta B/C (permisos de servidor,
> backups, DAM). Lo que **sí** entra al arnés como escenario es todo lo que
> se decide en el código: aislamiento por tenant, columnas que salen en un
> export, y qué se escribe en un log.

## Prioridad 1 — Aislamiento multi-tenant (el equivalente al IDOR en datos)

| Control | Cubeta | Qué exigir |
|---|---|---|
| Toda query filtra por tenant | A | consulta ejecutada en el contexto del tenant A no devuelve filas del tenant B |
| Filtro no depende de un parámetro del cliente | A | request que manda `tenant_id` de otro tenant → se ignora, se usa el del contexto autenticado |
| RLS como red de seguridad | B | tablas multi-tenant con política `RLS` activa (`pg_policies`); la app no es el único filtro |
| Migración no relaja protecciones | B | el diff de migración no hace `DISABLE ROW LEVEL SECURITY` ni `GRANT ALL` |

```gherkin
  @s3 @sec
  Scenario: Abuso: consultar pedidos forzando el tenant en el request
    Given el tenant "alfa" con 2 pedidos y el tenant "beta" con 5 pedidos
    And una sesión autenticada del tenant "alfa"
    When se listan pedidos indicando tenant "beta" en el request
    Then se devuelven los 2 pedidos de "alfa"
```

## Prioridad 2 — PII: qué sale y qué se registra

| Control | Cubeta | Qué exigir |
|---|---|---|
| Export con columnas mínimas | A | el CSV/Excel generado contiene solo las columnas del contrato; no `email`, `documento`, `teléfono` si no se pidieron |
| Masking/pseudonimización en entornos no productivos | A | el generador de datos de prueba no emite PII real |
| Nada de PII ni secretos en logs | A + B | A: el registro de la operación no contiene el email completo. B: grep de logs con el objeto entero |
| Agregados sin exponer individuos | A | un grupo con menos de N individuos se suprime o se agrupa, no se publica el conteo exacto |

```gherkin
  @s5 @sec
  Scenario: Abuso: el export de métricas arrastra datos personales
    Given 3 clientes con email y documento cargados
    When se exporta el reporte mensual de ventas
    Then el archivo tiene las columnas "mes", "cliente_id", "total"
    And el archivo no contiene ningún email
```

## Prioridad 3 — Superficie de la query

| Control | Cubeta | Qué exigir |
|---|---|---|
| Paginación obligatoria | A | pedir el listado sin parámetros devuelve como máximo N filas |
| Límite máximo de página | A | `per_page=100000` → se recorta al máximo permitido |
| Sin `SELECT *` hacia el borde | B | el serializador declara campos explícitos |
| Parametrización | A + B | ver `backend.md`, prioridad 2 |
| Timeout de query | B | toda query de reporte tiene límite de tiempo |

## Prioridad 4 — Pipelines ETL/ELT y notebooks

| Control | Cubeta | Qué exigir |
|---|---|---|
| Credenciales fuera del código | B | grep de DSN/keys en DAGs, scripts y `.ipynb` |
| Validación de esquema por paso | A | un registro malformado se rechaza y queda registrado; **no** se corrompe silenciosamente el destino |
| Aislamiento prod ↔ dev | B | el job de producción no escribe en datasets de desarrollo ni al revés |
| Notebooks sin salidas con datos | B | `.ipynb` commiteado con celdas de output limpias (`nbstripout`) |
| Idempotencia del job | A | re-ejecutar el mismo lote no duplica filas |

```gherkin
  @s7 @sec
  Scenario: Abuso: el lote trae una fila con esquema inválido
    Given un lote de 10 filas donde la fila 4 no tiene la columna "monto"
    When se ejecuta la carga
    Then se cargan 9 filas
    And la fila 4 queda registrada como rechazada con su motivo
```

## Cubeta B — checks de inspección para el modo `review`

```bash
# Credenciales / DSN en código, notebooks y DAGs
grep -rnE "(postgres|mysql|mongodb)(\+[a-z]+)?://[^ '\"]*:[^ '\"]*@" <archivos_del_diff>
# Salidas de notebook commiteadas
grep -ln '"output_type"' <archivos_del_diff>          # .ipynb con outputs
# Migraciones que relajan protecciones
grep -rnE "GRANT ALL|DISABLE ROW LEVEL SECURITY|TRUST|WITH GRANT OPTION" <archivos_del_diff>
# Objeto completo al log (arrastra PII)
grep -rnE "log(ger)?\.(info|debug)\(.*(row|record|payload|user)\b" <archivos_del_diff>
```

Checklist de config: cuenta de aplicación con permisos por tabla (no
`GRANT ALL`) · cuenta de lectura separada para reportes · TLS obligatorio en
la conexión · migraciones versionadas y reversibles · sin acceso directo de
analítica a tablas de escritura (vistas).

## Cubeta C — nómbralo y déjalo fuera

TDE y cifrado de volumen, backups y prueba de restore, pgAudit/DAM, revisión
trimestral de privilegios, cifrado a nivel de aplicación con KMS, privacidad
diferencial formal, data lineage, cumplimiento GDPR/HIPAA/PCI-DSS.
