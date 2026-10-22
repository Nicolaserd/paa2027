# Requisitos previos de un proyecto Power BI

Verificado contra la documentación oficial de Microsoft el 2026-10-22 (ver `.claude/pbi/verificacion-documental.md`).
Las versiones exactas y los orígenes de confianza están en `.claude/pbi/herramientas.json`.

## Las 6 herramientas

| # | Herramienta | Qué es realmente (nombre oficial y paquete) | Prioridad | Cómo se instala |
|---|---|---|---|---|
| 1 | Power BI Modeling MCP | Power BI Authoring MCP server, despliegue **local** (GA). npm `@microsoft/powerbi-modeling-mcp`, servidor `powerbi-modeling-mcp` | Obligatorio | Lo registra el plugin (#2) con `npx -y @microsoft/powerbi-modeling-mcp@latest --start` |
| 2 | powerbi-authoring | Plugin oficial `powerbi-authoring@fabric-collection` (repo `microsoft/skills-for-fabric`) | Obligatorio | `claude plugin marketplace add microsoft/skills-for-fabric` y `claude plugin install powerbi-authoring@fabric-collection --scope user` |
| 3 | Power BI Report Authoring CLI | npm `@microsoft/powerbi-report-authoring-cli`, comando `powerbi-report-author` (vista previa pública) | Necesaria (visuales) | `npm install -g @microsoft/powerbi-report-authoring-cli@<versión verificada>` |
| 4 | Power BI Desktop Bridge CLI | npm `@microsoft/powerbi-desktop-bridge-cli`, comando `powerbi-desktop` | Recomendada (diagnóstico) | `npm install -g @microsoft/powerbi-desktop-bridge-cli@<versión verificada>` |
| 5 | semantic-model-authoring | Skill del plugin #2 | Incluida | Llega con el plugin |
| 6 | Power BI Report skill | Skill `powerbi-report-cli` del plugin #2. **Unifica** las antiguas "report skills" (planning, design, authoring, management) | Incluida | Llega con el plugin |

## Prerrequisitos del equipo (no estaban en la lista original y son necesarios)

- **Windows**: el MCP local no funciona en macOS; Power BI Desktop y el Desktop Bridge son solo para Windows.
- **Power BI Desktop** firmado por Microsoft, versión 26.06 (junio de 2026) o posterior para tener el Desktop Bridge, y preferiblemente la última disponible.
- **Desktop Bridge habilitado**: Archivo > Opciones y configuración > Opciones > Seguridad > Desktop Bridge > "Enable external tool access to Power BI Desktop through secure local APIs" (activado por defecto). No debe existir la política `HKLM\SOFTWARE\Policies\Microsoft\Power BI Desktop\DesktopNamedPipeBridge = 0`.
- **Node.js LTS con soporte vigente, versión 22 o superior**. Las CLIs exigen ≥ 20 y el MCP ≥ 18, pero Node 20 perdió soporte el 2026-04-30.
- **Claude Code actualizado**: los plugins, hooks y `.claude/rules/` dependen de versiones recientes.
- **Git**: Microsoft recomienda un commit de línea base antes de que el agente haga cambios.

## Requisitos del proyecto

- El formato de trabajo es **PBIP**, no PBIX: el informe en **PBIR** (`*.Report/definition/`) y el modelo en **TMDL** (`*.SemanticModel/definition/*.tmdl`). La autoría local de reportes solo funciona con PBIR.
  - Si el proyecto solo tiene un `.pbix` o `.pbit`, o formatos antiguos, aplica la regla `pbi-05` y `/pbi-convertir-pbip`, que solo convierten cuando la tarea lo necesita.
- El proyecto debe estar en un **repositorio git con commit de línea base**.
- Antes de pedir cambios al agente, guarda en Desktop lo que hayas editado a mano: los archivos del disco son la fuente de verdad.

## No forma parte del preflight (solo para la nube)

Azure CLI (`az`), el MCP hospedado, el plugin `fabric-skills`, los permisos Write/Build sobre modelos del servicio y el endpoint XMLA en lectura/escritura **no** se instalan ni configuran al empezar. Solo se tratan con `/pbi-nube`, cuando el usuario lo pida (ver `pbi-03`).

## Cómo se verifica

- **Automático**: el hook `SessionStart` ejecuta `.claude/scripts/pbi-preflight.ps1`. Si el último resultado fue OK, usa la caché durante 24 h.
- **Manual**: `/pbi-preflight`, que también instala lo que falte después de confirmarlo con el usuario.
- **Resultados posibles**:
  - **BLOQUEADO**: falta algo obligatorio, necesario o de seguridad. No se empieza.
  - **AVISOS**: algo está desactualizado o es recomendado. Se informa al usuario.
  - **OK**: se puede empezar en local.
