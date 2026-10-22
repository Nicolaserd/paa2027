# Verificación documental: herramientas Power BI para agentes

**Fecha:** 2026-10-22. **Método:** lectura directa de learn.microsoft.com, de los manifiestos y skills en `github.com/microsoft/skills-for-fabric` y `github.com/microsoft/powerbi-modeling-mcp`, y del registro npm.

## 1. Lista original de herramientas: resultado

| # | Lista original | Verificación | Corrección |
|---|---|---|---|
| 1 | Power BI Modeling MCP (MCP oficial, obligatorio) | ✅ Existe. GA, npm `@microsoft/powerbi-modeling-mcp` 1.0.0 (2026-09-25), Microsoft | Microsoft ahora lo llama **Power BI Authoring MCP server (local)**. Hay además una versión **hospedada** (nube) que no debe registrarse a la vez que la local |
| 2 | powerbi-authoring (plugin oficial, obligatorio) | ✅ Plugin 0.3.19 del marketplace `fabric-collection` (`microsoft/skills-for-fabric`) | Registra el MCP local con `npx ...@latest --start` |
| 3 | Power BI Report Authoring CLI (necesaria para visuales) | ✅ npm `@microsoft/powerbi-report-authoring-cli` 0.5.0, comando `powerbi-report-author`, vista previa pública, Node ≥ 20 | No se instala con el plugin: es un `npm install -g` aparte |
| 4 | Power BI Desktop Bridge CLI (recomendada) | ✅ npm `@microsoft/powerbi-desktop-bridge-cli` 1.0.0, comando `powerbi-desktop`, Node ≥ 20 | La skill oficial no la usa para recargar ni capturar: queda como diagnóstico |
| 5 | semantic-model-authoring (incluida) | ✅ Skill del plugin | — |
| 6 | Power BI Report Skills (incluidas) | ⚠️ Ya no son varias skills | Ahora es **una** skill, `powerbi-report-cli` (Power BI Report skill), con módulos planning, design, authoring y management |

**Componentes que faltaban:**

- Power BI Desktop ≥ 26.06 con Desktop Bridge habilitado.
- Node.js LTS con soporte (Node 20 terminó el 2026-04-30).
- Claude Code actualizado.
- Git con línea base.
- Proyecto PBIP con PBIR y TMDL.
- Azure CLI, solo para la nube.

## 2. Matriz de responsabilidades propuesta: resultado

| Operación (original) | Responsable (original) | Veredicto | Detalle |
|---|---|---|---|
| Leer tablas y columnas | Modeling MCP | ✅ Correcto | Con el MCP conectado no se leen los `.tmdl` (anti-patrón oficial) |
| Crear y modificar medidas DAX | Modeling MCP | ✅ Correcto | Guiado por `semantic-model-authoring`. La primera escritura pide confirmación |
| Ejecutar consultas DAX | Modeling MCP | ✅ Correcto | Límite de 100.000 filas; los resultados llegan al modelo de lenguaje |
| Crear gráficos y tarjetas | Report Authoring Skills + CLI | ✅ Correcto, con el nombre corregido | Skill `powerbi-report-cli` + CLI `powerbi-report-author`. Requiere PBIR y que las medidas existan antes |
| Modificar páginas, formatos y botones | Report Authoring Skills + CLI | ✅ Correcto | Incluye filtros, slicers, marcadores y temas |
| Recargar cambios en Desktop | Desktop Bridge | ⚠️ Matiz | El transporte es el Bridge, pero el comando oficial es `powerbi-report-author preview --host desktop --reload` (o `--reload-with-model`), con `--status` antes. La skill prohíbe el comando directo del Bridge |
| Capturar y revisar páginas | Desktop Bridge | ⚠️ Separar | Capturar: `powerbi-report-author preview --host desktop --screenshot` (usa el Bridge). Revisar: la skill `powerbi-report-cli` (módulo design) |

**Operaciones que faltaban en la matriz:**

- Validar PBIR (`powerbi-report-author validate`).
- Planificación y design brief, con barrera de aprobación.
- Buenas prácticas y preparación del modelo para IA.
- Exportar a TMDL.
- Diagnóstico del Bridge (`powerbi-desktop status`).
- Línea base en git.
- Operaciones de **nube**: publicar o descargar reportes, desplegar o refrescar modelos, conectar el MCP a un workspace, preview en el servicio.

La matriz completa está en `.claude/rules/pbi-02-matriz-responsabilidades.md`.

## 4. Formato de trabajo: PBIP frente a PBIX (añadido el 2026-10-22, manifiesto 1.1.0)

| Afirmación | Veredicto | Fuente oficial |
|---|---|---|
| Esta configuración necesita PBIP, no PBIX | ✅ **Confirmado para reportes**: "Local report authoring requires PBIP projects that use the PBIR report format". Para el modelo, el MCP funciona en vivo sobre un PBIX abierto en Desktop, pero sin PBIP no hay diff ni reversión, y sin MCP ni PBIP la skill se detiene | Power BI Report skill; `semantic-model-authoring` (Tool Selection Priority) |
| Claude puede convertir PBIX → PBIP por sí mismo | ❌ **No**: "You can only convert a PBIX into a PBIP and vice-versa using Power BI Desktop's File > Save as" | PBIP overview (FAQ) |
| Exportar el modelo con el MCP equivale a convertir | ❌ **No**: el export solo genera el TMDL, sin la estructura PBIP ni el informe | `semantic-model-authoring`, "Export to PBIP" |
| PBIR es el formato por defecto | ✅ GA y por defecto. Un PBIR-Legacy se convierte al editarlo y guardarlo, con una copia de 30 días (Desktop de septiembre de 2026 o posterior) | PBIP report folder |
| TMDL es el formato por defecto | ⚠️ No confirmado en la documentación: se mantiene la opción de vista previa como camino | PBIP semantic model folder |
| Limitaciones de PBIP | Sin etiquetas de confidencialidad, sin Linguistic Schema, sin Report Server; ruta máxima de 260 caracteres; no se puede guardar directamente en OneDrive o SharePoint; `cache.abf` contiene datos y debe excluirse de git | PBIP overview, semantic model folder |

## 5. Fuentes oficiales

- Power BI Agentic overview: https://learn.microsoft.com/en-us/power-bi/developer/agentic/power-bi-agentic-overview (updated_at 2026-10-14)
- Power BI Authoring MCP server: https://learn.microsoft.com/en-us/power-bi/developer/mcp/power-bi-authoring-mcp (updated_at 2026-09-29)
- Semantic Model Authoring skill: https://learn.microsoft.com/en-us/power-bi/developer/agentic/semantic-model-authoring-skill-overview (updated_at 2026-09-17)
- Power BI Report skill: https://learn.microsoft.com/en-us/power-bi/developer/agentic/power-bi-report-skill-overview (updated_at 2026-10-02)
- Desktop Bridge: https://learn.microsoft.com/en-us/power-bi/developer/agentic/power-bi-desktop-bridge-overview (updated_at 2026-09-29)
- Plugin y marketplace: https://github.com/microsoft/skills-for-fabric (`plugins/powerbi-authoring/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`)
- MCP: https://github.com/microsoft/powerbi-modeling-mcp (README: flags, EULA, variables de entorno)
- Power BI Desktop projects (PBIP): https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview (updated_at 2026-09-29)
- PBIP report folder (PBIR): https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report (updated_at 2026-09-29)
- PBIP semantic model folder (TMDL, `.pbi`): https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset (updated_at 2026-09-29)
- Registro npm: `@microsoft/powerbi-modeling-mcp`, `@microsoft/powerbi-report-authoring-cli`, `@microsoft/powerbi-desktop-bridge-cli`, todos publicados por `microsoft1es` / `microsoft-oss-releases`

## Historial

- **2026-10-22**: verificación inicial; manifiesto 1.0.0.
- **2026-10-22**: añadidos la regla `pbi-05` (PBIP como formato de trabajo y conversión por casos), la skill `/pbi-convertir-pbip`, el script `pbi-formato.ps1`, la fila 0 de la matriz y 3 fuentes de PBIP; manifiesto 1.1.0.
