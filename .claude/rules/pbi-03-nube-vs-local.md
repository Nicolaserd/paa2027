# Nube vs. local

**Por defecto todo se hace en LOCAL**: Power BI Desktop, PBIP/TMDL/PBIR en disco, el MCP local y las CLIs.

## Qué cuenta como "nube"

Cualquier operación que se autentica en Microsoft Entra ID o lee o escribe en un tenant:

- Power BI Service o Fabric: publicar, descargar, desplegar, refrescar, cambiar permisos, orígenes o conexiones.
- Conectar el MCP a un workspace o a un endpoint XMLA (`powerbi://`, `asazure://`).
- `az login`, `az rest`, `fab`, `Connect-PowerBIServiceAccount`, `Invoke-PowerBIRestMethod`, `Connect-AzAccount`.
- Llamadas a `api.powerbi.com`, `api.fabric.microsoft.com`, OneLake o `login.microsoftonline.com`.
- `powerbi-report-author preview --host service`.
- Registrar o usar el **MCP hospedado** (`https://api.fabric.microsoft.com/v1/mcp/powerbi/authoring`) o instalar el plugin `fabric-skills`, que registra MCP hospedados de Fabric.

**No** cuenta como nube leer información pública sin credenciales para comprobar si algo está vigente: el registro de npm, GitHub (raw), learn.microsoft.com, nodejs.org o winget.

## Protocolo obligatorio antes de usar la nube (`/pbi-nube`)

1. **Para y pregunta** antes de ejecutar nada. Explica:
   - qué operación quieres hacer;
   - contra qué workspace o modelo;
   - qué datos o metadatos salen del equipo;
   - qué permisos hacen falta.
2. Ofrece **tres opciones** (con AskUserQuestion):
   - **Hazlo tú (Claude)**: Claude lo ejecuta dentro del alcance aprobado. Claude no puede escribir credenciales: el inicio de sesión lo completa siempre el usuario en el navegador.
   - **Dime los pasos y lo hago yo**: Claude da los comandos exactos y el orden, y no ejecuta nada en la nube.
   - **Seguir solo en local**: Claude propone la alternativa local (PBIP, Desktop, validación y capturas locales).
3. Solo con "Hazlo tú", registra la aprobación temporal con
   `.claude/scripts/pbi-nube.ps1 -Accion aprobar -Alcance "<qué y dónde>"`.
   Ese comando siempre pide confirmación del usuario. Dura 2 h por defecto y 8 h como máximo, y caduca al empezar otra sesión.
4. Al terminar, revócala: `.claude/scripts/pbi-nube.ps1 -Accion revocar`.

## Prohibido

- Conectarse a la nube "de paso" para completar otra tarea, por ejemplo publicar un trabajo a medias para poder previsualizarlo.
- Tener registrados a la vez el MCP local y el hospedado: Microsoft lo desaconseja porque el agente no sabe a cuál enrutar.
- Pedir, mostrar o guardar en archivos del proyecto contraseñas, tokens o secretos de service principal.
- Añadir hosts a `PBI_MODELING_MCP_ALLOWED_CONNECTION_HOSTS` sin confirmar quién opera ese endpoint: los tokens de acceso se envían a esos hosts.

## Mecanismos que hacen cumplir esta regla

- El hook `PreToolUse` (`.claude/hooks/guard-nube.ps1`) detecta comandos y llamadas MCP de nube y obliga a confirmar, salvo que haya una aprobación vigente.
- Las reglas `permissions.ask` de `.claude/settings.json` piden confirmación para `az login`, el MCP hospedado, `fabric-skills` y la aprobación de nube en cualquier modo de permisos, incluido bypass.
