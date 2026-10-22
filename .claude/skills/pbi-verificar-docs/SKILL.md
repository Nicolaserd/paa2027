---
name: pbi-verificar-docs
description: Vuelve a verificar la documentación oficial de Microsoft sobre las herramientas Power BI para agentes (Power BI Authoring/Modeling MCP, plugin powerbi-authoring, skills semantic-model-authoring y powerbi-report-cli, CLIs powerbi-report-author y powerbi-desktop, Desktop Bridge). Luego actualiza la matriz de responsabilidades, las reglas y el manifiesto herramientas.json si algo cambió. Usar cuando el preflight informe "documentación cambiada", "manifiesto oficial cambió" o un fallo de seguridad de paquete; al empezar un proyecto si la última verificación tiene más de 30 días; o cuando el usuario pregunte si las reglas o la matriz siguen vigentes.
---

# Verificar la documentación oficial y actualizar las reglas

## 1. Cargar lo que hay hoy

- `.claude/pbi/herramientas.json`: versiones verificadas, `fuentes` con `updatedAtVerificado` y patrones de nube.
- `.claude/rules/pbi-01-requisitos-previos.md` y `.claude/rules/pbi-02-matriz-responsabilidades.md`.
- `.claude/pbi/estado/preflight.json` (sección `docsCambiadas`), si existe.

## 2. Leer las fuentes oficiales (solo estas)

| Fuente | Cómo leerla | Qué extraer |
|---|---|---|
| Páginas Learn de `fuentes` (tipo `learn`) | WebFetch. Para la fecha, `Invoke-WebRequest` y el meta `updated_at` | Nombres de herramientas, comandos de instalación, prerrequisitos (Node, Desktop), local frente a hospedado, ajustes de tenant, límites, avisos de seguridad |
| `plugin.json` y `marketplace.json` oficiales | `Invoke-RestMethod` a la URL raw | Versión del plugin, lista de skills, configuración del MCP (paquete, transporte, argumentos), plugins que registran servidores de nube |
| `SKILL.md` de `powerbi-report-cli` y de `semantic-model-authoring` | `Invoke-WebRequest` a la URL raw | Comandos de `powerbi-report-author` (validate, preview, `--status`, `--reload`), prioridad de herramientas, barreras de aprobación |
| README del MCP | `Invoke-WebRequest` a la URL raw | Flags (`--readonly`, `--readwrite`, `--authmode`), variables de entorno, EULA |
| Registro npm | `Invoke-RestMethod https://registry.npmjs.org/<paquete codificado>/latest` | Versión, `engines.node`, mantenedores, repositorio, `deprecated` |

Los blogs y sitios de terceros solo sirven como pista de dónde mirar. **Nunca** cambies una regla basándote en ellos.

## 3. Comparar y presentar las diferencias

Haz una tabla con: elemento, lo que dicen hoy las reglas o el manifiesto, lo que dice ahora la fuente oficial, y la URL. Revisa como mínimo:

- Renombrados o fusiones de herramientas o skills (por ejemplo, skills unificadas).
- Paquetes, comandos o flags nuevos o retirados.
- Cambios de responsable en la matriz (qué herramienta hace cada operación) y operaciones nuevas.
- Prerrequisitos: versión mínima de Node o de Power BI Desktop, sistema operativo.
- Novedades de nube: endpoints, ajustes de tenant, servidores hospedados, plugins que los registran.
- Seguridad: mantenedores o repositorio distintos, `deprecated`, avisos nuevos.

Si una página oficial ya no existe, búscala de nuevo en learn.microsoft.com y propón la URL nueva.

## 4. Pedir confirmación

Pregunta con AskUserQuestion:

- **Aplicar todos los cambios**
- **Revisar uno por uno**
- **No aplicar**

Cualquier cambio que **relaje** una regla de nube o de seguridad necesita su propia confirmación explícita.

## 5. Aplicar (solo lo confirmado)

1. Edita las reglas afectadas (`pbi-01` a `pbi-05`) y `CLAUDE.md` si cambia la puerta de entrada o los skills. Si cambian los formatos PBIP, PBIR o TMDL, o la forma de convertir, actualiza también `pbi-05`, `/pbi-convertir-pbip` y la sección `formato` del manifiesto.
2. Actualiza `herramientas.json`:
   - `versionVerificada`, `skillsEsperadas`, `fuentes[].updatedAtVerificado` (con el `updated_at` leído) y `fuentes[].url`;
   - patrones de nube si aparecieron endpoints nuevos;
   - `verificadoEl` con la fecha de hoy;
   - `version`: sube el último número, o el del medio si cambia una regla.
3. Añade una entrada al historial al final de `.claude/pbi/verificacion-documental.md` con la fecha, qué cambió y las fuentes.
4. Vuelve a ejecutar `/pbi-preflight`. Como cambió la versión del manifiesto, el hook de inicio también lo repetirá en la próxima sesión.

## 6. Cerrar

Resume en 3 a 5 líneas qué cambió y qué no, e indica si el preflight quedó en OK.
