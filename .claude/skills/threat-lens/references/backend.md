# Perfil `backend` — controles, escenarios y checks

> Cargar solo si la feature toca handlers HTTP, casos de uso de servidor,
> queries a DB, ejecución de comandos o llamadas HTTP salientes.
> Cubeta **A** = escenario `@sec`. Cubeta **B** = check de inspección.

## Prioridad 1 — Autorización y ownership (A01, el más caro y el más olvidado)

| Control | Riesgo | Escenario `@sec` |
|---|---|---|
| Ownership del recurso | IDOR / A01 | usuario B pide el recurso de A → 404 (no 403: 403 confirma que existe) |
| Rol requerido por endpoint | Elevación de privilegio | usuario normal llama endpoint de admin → 403, y el efecto **no** ocurrió |
| Sin credencial | Auth bypass | request sin token / con token expirado → 401 |
| Permiso revalidado, no cacheado | Mediación completa | usuario degradado a mitad de sesión → siguiente request → 403 |

```gherkin
  @s5 @sec
  Scenario: Abuso: un usuario sin rol admin borra un artículo
    Given un usuario autenticado "beto" con rol "lector"
    And un artículo 42 existente
    When "beto" solicita borrar el artículo 42
    Then la respuesta tiene código 403
    And el artículo 42 sigue existiendo
```

El segundo `Then` es el que importa: sin él, un test pasa aunque el handler
devuelva 403 **después** de haber borrado.

## Prioridad 2 — Inyección, según el sink de la feature (A03)

Elige **el sink que esta feature realmente usa**, no los cinco.

| Sink | Riesgo | Cubeta | Qué exigir |
|---|---|---|---|
| Query SQL | SQLi | A + B | A: término con `' OR '1'='1` devuelve 0 filas y no error. B: grep de f-string/concat/`%`/`+` sobre SQL |
| Comando de SO | Command injection | A + B | A: argumento con `; ls` no ejecuta nada extra. B: `shell=True`, `exec(`, backticks |
| Template | SSTI → RCE | A | input `{{7*7}}` se renderiza literal, no como `49` |
| Parser XML | XXE | A + B | A: XML con DTD externa → rechazado. B: parser sin `defusedxml`/`disallow-doctype-decl` |
| Deserialización | RCE | B | grep `pickle.loads`, `yaml.load` sin `SafeLoader`, `BinaryFormatter`, `ObjectInputStream` |
| Log | Log forging | A | input con `\n` no produce una línea de log falsa |

```gherkin
  @s6 @sec
  Scenario: Abuso: el nombre de archivo lleva un separador de comandos
    Given un directorio de trabajo vacío
    When se procesa el archivo llamado "informe.csv; rm -rf ."
    Then se reporta un error de nombre inválido con código de salida 2
    And el directorio de trabajo sigue vacío
```

## Prioridad 3 — Validación de entrada y límites (A04/A05, DoS)

| Control | Escenario `@sec` |
|---|---|
| Esquema estricto | campo de tipo equivocado / enum fuera de rango → 400 con error de validación |
| Campos inesperados | payload con campo extra → rechazado, no ignorado silenciosamente (evita mass assignment: `{"rol":"admin"}`) |
| Tamaño de payload | body por encima del límite → 413, sin cargar todo en memoria |
| Profundidad de JSON | JSON con 200 niveles → 400, no stack overflow |
| Longitud de string / tamaño de array | campo de 10 MB → 400 |
| Rangos numéricos | cantidad negativa o mayor a `MAX_SAFE_INTEGER` → 400 |
| Regex sin backtracking catastrófico | ReDoS | B: revisar cuantificadores anidados en regex del diff; A si hay input libre: cadena patológica responde bajo un timeout |

**Mass assignment merece un escenario propio** si la feature acepta un objeto
y lo mapea a una entidad: es la forma más común de elevación de privilegio
en un CRUD.

## Prioridad 4 — Qué filtra el error (A09 / information disclosure)

| Control | Escenario `@sec` |
|---|---|
| Error genérico al cliente | input malformado → cuerpo sin stack trace, sin ruta de archivo, sin nombre de tabla |
| Error interno completo al log | el mismo caso → hay una entrada de log con el detalle y un id de correlación |
| Sin oráculo de existencia | login con usuario inexistente y con password errónea → **el mismo** mensaje y el mismo tiempo aproximado |

## Prioridad 5 — Lógica de negocio (no la detecta ningún SAST)

Los bugs más caros y los que mejor encajan en este arnés, porque son
exactamente escenarios Gherkin:

| Abuso | Escenario `@sec` |
|---|---|
| Precio desde el cliente | orden con precio manipulado → se registra el precio del catálogo |
| Cupón reusado | aplicar el mismo cupón de un uso dos veces → la segunda falla y el total no baja |
| Descuento negativo | descuento `-50` → 400, el total no sube el saldo del usuario |
| Salto de pasos | pagar sin haber pasado por confirmación → rechazado |
| Límite ignorado | superar el máximo por cuenta → rechazado en el intento N+1 |
| Race condition | 2 compras concurrentes con stock 1 → una gana, la otra falla, stock final 0 |
| Idempotencia | mismo `Idempotency-Key` dos veces → un solo cargo |

```gherkin
  @s9 @sec
  Scenario: Abuso: el mismo cupón de un solo uso se canjea dos veces
    Given un cupón "VERANO" de un solo uso, 10% de descuento
    And un carrito de 200
    When se aplica "VERANO" y luego se aplica "VERANO" otra vez
    Then el segundo intento falla con "cupón ya utilizado"
    And el total del carrito es 180
```

La race condition necesita concurrencia real en el test (hilos/tasks + un
recurso aislado real, no un mock — ver C4 en `CHECKPOINTS.md`). Si el stack no
lo permite barato, dilo en `risks` y muévelo a Cubeta C en vez de fingirlo.

## Prioridad 6 — Salidas del servidor (SSRF, A10) y entradas de archivo

| Control | Cubeta | Qué exigir |
|---|---|---|
| Whitelist de destino | A | URL a `http://169.254.169.254/…` o `http://127.0.0.1` → rechazada antes de hacer el request |
| Sin redirect ciego | A | destino permitido que redirige a IP interna → rechazado |
| Path traversal | A | nombre `../../etc/passwd` → rechazado; la ruta resuelta queda dentro del directorio base |
| Upload: MIME + extensión + magic bytes | A | archivo `.png` cuyo contenido es un ejecutable → rechazado |
| Upload: nombre y ubicación | A/B | se guarda con nombre generado, fuera del document root; el nombre original no llega al filesystem |
| Límite de tamaño y cantidad | A | por encima del límite → rechazado |

## Cubeta B — checks de inspección para el modo `review`

Solo sobre archivos tocados por la feature.

```bash
# Concatenación en SQL (ajusta al lenguaje)
grep -rnE "(SELECT|INSERT|UPDATE|DELETE)[^\"']*(\+|%s|\\$\{|f\")" <archivos_del_diff>
# Ejecución de shell
grep -rnE "shell=True|os\.system|exec\(|eval\(|child_process\.exec\(" <archivos_del_diff>
# Deserialización insegura
grep -rnE "pickle\.loads|yaml\.load\((?!.*SafeLoader)|BinaryFormatter" <archivos_del_diff>
# Error crudo al cliente
grep -rnE "str\(e(xc)?\)|\.stack|traceback\.format_exc" <archivos_del_diff>
# CORS abierto con credenciales
grep -rnE "Allow-Origin.*\*|origin: *['\"]\*" <archivos_del_diff>
# Secretos
grep -rnE "(api[_-]?key|secret|token|password)\s*[:=]\s*['\"][^'\"]{12,}" <archivos_del_diff>
```

Checklist de config a mirar (bloqueante solo si el diff la introduce o la
cambia): CORS con whitelist explícita por entorno · rate limiting en endpoints
públicos y **más estricto en auth** · timeouts en toda llamada externa · modo
debug apagado en producción · hashing de passwords con Argon2id o bcrypt
cost ≥ 12 · JWT con `alg` validado y expiración corta · sesión regenerada tras
login.

## Cubeta C — nómbralo y déjalo fuera

WAF, DDoS, mTLS entre servicios, segmentación de red, SIEM, rotación
automática de credenciales, HSM/KMS, pentest, red team.
