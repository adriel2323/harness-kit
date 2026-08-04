# Perfil `frontend` — controles, escenarios y checks

> Cargar solo si la feature toca DOM, componentes, rutas de SPA, storage del
> navegador o comunicación cross-origin.
>
> **Advertencia de encuadre:** la validación de frontend es **UX, no
> seguridad**. Si un `@sec` del frontend es el único control de una regla, el
> control no existe — el backend tiene que repetirlo. Cuando propongas un
> `@sec` de frontend, revisa que exista su gemelo de backend o dilo en
> `risks`.

## Prioridad 1 — XSS (el vector propio del frontend)

| Control | Cubeta | Qué exigir |
|---|---|---|
| Nada de HTML crudo con dato no confiable | A + B | A: un campo con `<img src=x onerror=…>` se renderiza como texto visible, no como elemento. B: grep de `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `[innerHTML]`, `document.write` |
| Atributos por API, no por concatenación | B | grep de plantillas que arman HTML con `+` o interpolación |
| Sanitización en output, nunca en input | A | el dato se guarda tal cual y se escapa al mostrarlo |

```gherkin
  @s4 @sec
  Scenario: Abuso: el nombre de usuario trae una etiqueta de script
    Given un usuario cuyo nombre es "<img src=x onerror=alert(1)>"
    When se renderiza su tarjeta de perfil
    Then el texto visible contiene "<img src=x onerror=alert(1)>"
    And el documento no contiene ningún elemento "img"
```

El segundo `Then` es el control real. El primero solo evita que "escapar" se
implemente como "borrar el campo".

## Prioridad 2 — Comunicación cross-origin y navegación

| Control | Cubeta | Qué exigir |
|---|---|---|
| `postMessage` valida `origin` | A + B | A: mensaje desde un origin no permitido → se ignora, sin cambio de estado. B: grep `addEventListener('message'` sin comprobación de `event.origin` |
| Open redirect | A | `?next=https://evil.com` y `?next=javascript:…` → rechazados; solo whitelist |
| Tab-nabbing | B | grep `target="_blank"` sin `rel="noopener noreferrer"` |
| iframe de terceros | B | atributo `sandbox` presente y sin `allow-top-navigation` |

```gherkin
  @s6 @sec
  Scenario: Abuso: mensaje postMessage desde un origen no autorizado
    Given el widget escuchando mensajes con origen permitido "https://app.local"
    When llega un mensaje {"accion":"cerrarSesion"} desde "https://evil.example"
    Then la sesión sigue activa
```

## Prioridad 3 — Almacenamiento y sesión en el cliente

| Control | Cubeta | Qué exigir |
|---|---|---|
| Token de sesión **nunca** en `localStorage`/`sessionStorage` | A + B | A: tras login, el storage no contiene el token. B: grep `localStorage.setItem` con token/jwt/auth |
| Cookie con `Secure`, `HttpOnly`, `SameSite` | B | inspección de dónde se emite la cookie (normalmente backend) |
| Sin datos sensibles en el estado global expuesto | A | el estado serializado no contiene PII más allá de lo que la vista muestra |
| Service Worker no cachea respuestas autenticadas | B | revisar la estrategia de cache del SW |

## Prioridad 4 — Trampas de JavaScript

| Control | Cubeta | Qué exigir |
|---|---|---|
| Prototype pollution | A + B | A: payload `{"__proto__":{"esAdmin":true}}` en un merge → `({}).esAdmin` sigue undefined. B: grep de merge/extend profundo sobre input externo |
| DOM clobbering | B | grep `window[nombre]`, `document.forms`, `getElementsByName` con dato de usuario |
| Sin `eval` / `Function` / `setTimeout(string)` | B | grep directo |

```gherkin
  @s7 @sec
  Scenario: Abuso: la configuración importada intenta contaminar el prototipo
    Given la configuración por defecto sin la clave "esAdmin"
    When se importa la configuración {"__proto__": {"esAdmin": true}}
    Then un objeto vacío nuevo no tiene la propiedad "esAdmin"
```

## Cubeta B — checks de inspección para el modo `review`

```bash
grep -rnE "innerHTML|dangerouslySetInnerHTML|v-html|document\.write" <archivos_del_diff>
grep -rnE "localStorage\.setItem\(.*(token|jwt|auth|secret)" <archivos_del_diff>
grep -rn  "target=\"_blank\"" <archivos_del_diff>   # debe traer rel="noopener noreferrer"
grep -rnE "addEventListener\(\s*['\"]message['\"]" <archivos_del_diff>  # ¿valida event.origin?
grep -rnE "eval\(|new Function\(" <archivos_del_diff>
grep -rn  "<script src=\"http" <archivos_del_diff>  # CDN externo: exige integrity=sha384-…
```

Checklist de config (bloqueante solo si el diff la toca): CSP sin
`unsafe-inline` ni `unsafe-eval` · `X-Content-Type-Options: nosniff` ·
`frame-ancestors 'self'` (mejor que `X-Frame-Options`) · HSTS ·
`Referrer-Policy` · SRI en todo recurso de CDN.

## Cubeta C — nómbralo y déjalo fuera

Auditoría de scripts de terceros en producción (Magecart), certificate
pinning en móvil, grading de `securityheaders.com` / SSL Labs, keylogging
por extensiones del navegador.
