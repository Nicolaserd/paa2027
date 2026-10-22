# Seguridad y vigencia de las herramientas

## Cuándo una herramienta está "vigente"

- Su versión instalada es la última publicada en el canal oficial (npm, marketplace `fabric-collection`, winget o Microsoft Store), o la diferencia está justificada y avisada.
- No está marcada como `deprecated` en npm.
- Su entorno de ejecución tiene soporte: Node.js con soporte de seguridad vigente (≥ 22), Power BI Desktop ≥ 26.06, Claude Code reciente.
- La documentación oficial no ha cambiado desde la última verificación. Si cambió, se ejecuta `/pbi-verificar-docs`.

## Cuándo una herramienta es "segura"

- **Paquetes npm**:
  - publicados por las cuentas de Microsoft (`microsoft1es`, `microsoft-oss-releases`);
  - su campo `repository` apunta a `github.com/microsoft/powerbi-modeling-mcp` o `github.com/microsoft/skills-for-fabric`.
- **Marketplace**: el nombre `fabric-collection` debe apuntar exactamente a `microsoft/skills-for-fabric`. Otro origen con ese nombre es una suplantación: no se instala nada desde ahí.
- **Binarios** (Power BI Desktop y el `.exe` del MCP que descarga npx): firma Authenticode válida de "Microsoft Corporation".
- **Solo fuentes oficiales**: learn.microsoft.com, github.com/microsoft y el registro npm `@microsoft`. Los blogs y sitios de terceros sirven como pista, nunca como base para instalar ni para cambiar reglas.

Si cualquiera de estos controles falla: **no instales ni actualices**. Avisa al usuario con el detalle y ejecuta `/pbi-verificar-docs`.

## Instalación segura

- Antes de instalar o actualizar, enseña el plan completo y pide **una** confirmación al usuario.
- Fija versiones exactas en las instalaciones globales: `npm install -g <paquete>@<versión verificada>`, nunca `@latest`.
- El plugin oficial registra el MCP con `@latest` mediante npx. Por eso el preflight verifica en cada ejecución quién publicó esa versión y la firma del binario descargado.
- Después de instalar o actualizar el plugin, **reinicia Claude Code** para que cargue el MCP y las skills, y vuelve a ejecutar `/pbi-preflight`.
- Lo que necesita elevación de permisos (actualizar Power BI Desktop o Node.js con winget) se le indica al usuario. Solo lo ejecuta Claude si el usuario lo pide.

## Uso seguro del MCP

- **EULA**: el MCP bloquea sus herramientas hasta aceptar la EULA. Nunca la aceptes (`accept_eula`, `--accepteula`, `PBI_MODELING_MCP_ACCEPT_EULA`) sin la autorización explícita del usuario después de que la haya leído.
- **Escritura**: por defecto el MCP pide confirmación antes de la primera escritura en cada modelo (`--readwrite`). Para explorar modelos sensibles o de producción, propón el modo `--readonly`.
- **Privacidad**: los metadatos y los resultados de las consultas DAX llegan al modelo de lenguaje. No consultes datos personales o confidenciales sin necesidad, y avisa antes de hacerlo.
- **Respaldo**: haz un commit o una copia del modelo antes de cambios masivos (renombrados, traducciones, refactorizaciones).
