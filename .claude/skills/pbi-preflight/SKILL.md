---
name: pbi-preflight
description: Verifica e instala los requisitos previos de un proyecto Power BI antes de empezar. Revisa el plugin oficial powerbi-authoring, el Power BI Modeling MCP, las CLIs powerbi-report-author y powerbi-desktop, las skills semantic-model-authoring y powerbi-report-cli, Power BI Desktop con Desktop Bridge, Node.js, Claude Code, Git y el formato PBIP/PBIR/TMDL, comprobando que estén vigentes y sean seguras. Usar al empezar un proyecto Power BI, cuando el hook de inicio informe BLOQUEADO o AVISOS, antes de la primera tarea de modelado o de reportes, o cuando el usuario pida "preflight", "verificar herramientas", "instalar las herramientas de Power BI" o "¿está todo listo?".
---

# Preflight de Power BI

Objetivo: dejar el equipo y el proyecto listos para trabajar en **local** con las herramientas oficiales de Microsoft. Este skill **nunca** se conecta a la nube; eso es `/pbi-nube`.

## 1. Verificar

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-preflight.ps1 -Guardar
```

- Añade `-SinRed` si el usuario no quiere consultas a registros públicos (npm, GitHub, Learn, nodejs.org, winget). En ese caso la vigencia queda sin verificar y hay que decirlo.
- El script solo lee. El resultado queda en `.claude/pbi/estado/preflight.json`, que también usa el hook de inicio.

## 2. Informar al usuario

Resume en una tabla corta lo que **no** está en OK, agrupado así:

1. **Bloqueantes**: FALLA en obligatorio, necesaria, prerequisito, incluida o seguridad.
2. **Avisos**: versiones desactualizadas, recomendadas que faltan, proyecto sin git, documentación cambiada.
3. **Informativos**: Bridge no verificable con Desktop cerrado, pbi-cli de terceros, Azure CLI.

Si algún check de **seguridad** falla (publicador, repositorio, firma, marketplace suplantado, versión deprecated), dilo primero y **no instales nada relacionado**. Propón `/pbi-verificar-docs`.

## 3. Pedir una sola confirmación

Muestra el plan del script (sección "Plan sugerido") en orden y pregunta con AskUserQuestion:

- **Instalar o actualizar todo lo automático** (recomendado)
- **Elegir qué instalar**
- **No instalar ahora**: el resultado queda BLOQUEADO o AVISOS y se respeta la puerta de entrada.

Los pasos marcados `[manual]` son para el usuario, porque requieren elevación o la interfaz de Desktop. Explica cómo hacerlos y ejecútalos solo si el usuario lo pide expresamente.

## 4. Ejecutar el plan (solo lo confirmado, en este orden)

| Orden | Paso | Comando |
|---|---|---|
| 10 | Claude Code | `claude update` |
| 20 | Node.js LTS (si falta o no tiene soporte) | `winget install --id OpenJS.NodeJS.LTS -e --source winget` |
| 25 | Git (si falta) | `winget install --id Git.Git -e --source winget` |
| 28 | Power BI Desktop `[manual]` | Microsoft Store, o `winget install/upgrade --id Microsoft.PowerBI -e --source winget` con Desktop cerrado |
| 30 | Marketplace oficial | `claude plugin marketplace add microsoft/skills-for-fabric` |
| 40 | Plugin oficial | `claude plugin install powerbi-authoring@fabric-collection --scope user` (o `update` / `enable`) |
| 50 | CLIs, con la versión exacta que dio el script | `npm install -g @microsoft/powerbi-report-authoring-cli@X.Y.Z` y `npm install -g @microsoft/powerbi-desktop-bridge-cli@X.Y.Z` |
| 60 | Desktop Bridge `[manual]` | Desktop > Archivo > Opciones y configuración > Opciones > Seguridad > Desktop Bridge |
| 70 | Línea base git del proyecto | `git init`, `git add -A`, `git commit -m "Linea base antes de cambios del agente"`, solo si el usuario lo confirma |

Reglas:

- Antes de ejecutar un paso de marketplace, plugin o CLI, comprueba que el script lo verificó en línea y sin problemas de seguridad. Nunca uses `@latest` en `npm install -g`.
- Si un comando falla, para, muestra el error tal cual y no sigas con los pasos que dependen de él.
- **No** instales `fabric-skills`, el MCP hospedado ni Azure CLI aquí. Son nube: `/pbi-nube`.

## 5. Después de instalar

1. Si se instaló o actualizó el plugin o Claude Code, pide al usuario que **reinicie Claude Code** (cerrar y volver a abrir la sesión). Sin reiniciar no cargan el MCP ni las skills.
2. Vuelve a ejecutar el paso 1 hasta que el resultado sea OK o queden solo avisos aceptados por el usuario.
3. **Primer uso del MCP**: bloquea sus herramientas hasta aceptar la EULA. Enlaza la EULA (`https://github.com/microsoft/powerbi-modeling-mcp/blob/main/EULA.txt`) y llama a `accept_eula` solo si el usuario autoriza explícitamente después de haberla leído.
4. Prueba de humo, en local y con Desktop abierto con un modelo: `/semantic-model-authoring Connect to Power BI Desktop and analyze the semantic model against best practices`. Para reportes: `powerbi-report-author preview --list-hosts`.

## 6. Cerrar

Informa el resultado final en una línea: OK, AVISOS aceptados o BLOQUEADO con qué falta. Si queda BLOQUEADO, recuerda que no se empieza el trabajo de Power BI hasta resolverlo, salvo autorización explícita del usuario.
