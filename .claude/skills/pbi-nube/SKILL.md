---
name: pbi-nube
description: Protocolo obligatorio antes de cualquier operación de Power BI que se conecte a la nube (Power BI Service, Microsoft Fabric, Entra ID). Cubre publicar, descargar o actualizar reportes en un workspace, desplegar o refrescar modelos semánticos, cambiar orígenes, permisos o conexiones, conectar el MCP a un workspace o endpoint XMLA, az login o az rest, preview --host service, el MCP hospedado y el plugin fabric-skills. Usar cuando el usuario pida publicar, desplegar, subir, refrescar en el servicio o conectar a un workspace, o cuando el hook guard-nube pida confirmación.
---

# Protocolo de nube para Power BI

El proyecto trabaja en **local** por defecto (regla `pbi-03`). Este skill decide **si**, **cómo** y **quién** hace una operación en la nube.

## 1. Parar y explicar (antes de ejecutar nada)

Explica al usuario en pocas líneas:

- **Qué** operación quieres hacer y **por qué** hace falta la nube (¿hay alternativa local?).
- **Contra qué**: tenant, workspace, modelo o reporte (por nombre).
- **Qué sale del equipo**: definiciones PBIR/TMDL, metadatos y, en consultas DAX remotas, datos que llegarán al modelo de lenguaje.
- **Qué se necesita**:
  - Azure CLI (`az`) con sesión iniciada;
  - permiso **Write** sobre el modelo (o **Build** para solo consultar);
  - endpoint XMLA en **Read Write** en la capacidad, si el MCP local se conecta a Fabric;
  - para el MCP hospedado, el ajuste de tenant "Users can use the Power BI Model Context Protocol server endpoint".

## 2. Preguntar con AskUserQuestion (siempre)

Pregunta: "¿Cómo quieres hacer <operación> en <destino>?"

1. **Hazlo tú (Claude)**: ejecuto los pasos dentro del alcance aprobado. El inicio de sesión lo completas tú en el navegador.
2. **Dime los pasos y lo hago yo**: te doy los comandos exactos y no ejecuto nada en la nube.
3. **Seguir solo en local**: te propongo la alternativa local.

## 3a. Opción "Hazlo tú"

1. Comprueba los requisitos locales: `az --version`. Si falta, propón `winget install --id Microsoft.AzureCLI -e --source winget` y espera la confirmación.
2. Registra la aprobación temporal (Claude Code pedirá confirmación al usuario):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-nube.ps1 -Accion aprobar -Horas 2 -Alcance "<operación> en <workspace/modelo>"
   ```
3. Inicio de sesión: `az login --allow-no-subscriptions --tenant <tenantId>`. Se abre el navegador y el usuario se autentica. Nunca pidas ni escribas contraseñas, tokens ni secretos.
4. Ejecuta **solo** lo aprobado, con la skill oficial correspondiente:
   - Reportes: `powerbi-report-cli` (módulo management).
   - Modelos: `semantic-model-authoring`. Desde PBIP/TMDL, el despliegue es siempre por API REST.
5. Verifica el resultado leyéndolo de vuelta, como exige el flujo oficial.
6. Revoca al terminar:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-nube.ps1 -Accion revocar
   ```

## 3b. Opción "Dime los pasos"

Entrega una lista numerada con los comandos exactos, los nombres reales de workspace y modelo, el orden, cómo verificar cada paso y cómo deshacerlo. No ejecutes ninguno de esos comandos.

## 3c. Opción "Seguir solo en local"

Propón la alternativa local:

- Guardar como PBIP.
- Validar con `powerbi-report-author validate`.
- Recargar y capturar en Desktop con `preview --host desktop`.
- Hacer commit en git.

Deja la publicación como paso pendiente para el usuario.

## Nunca

- Registrar el MCP hospedado o instalar `fabric-skills` en un proyecto que usa el MCP local, salvo que el usuario lo decida tras saber que Microsoft desaconseja tener ambos.
- Publicar un trabajo a medias como efecto secundario de otra tarea, por ejemplo para previsualizarlo.
- Guardar credenciales o secretos de service principal en archivos del proyecto.
- Ampliar el alcance aprobado (otro workspace, otro modelo, borrar elementos) sin volver al paso 2.
