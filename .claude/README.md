# Plantilla `.claude/` para proyectos Power BI

Reglas, skills, hooks y requisitos que deben estar listos **antes** de empezar cualquier proyecto Power BI con Claude Code.

## Contenido

```
.claude/
├── CLAUDE.md                          Puerta de entrada y mapa de la plantilla (se carga siempre)
├── settings.json                      Hooks + reglas de permiso (ask/deny) para la nube
├── rules/                             Se cargan solas al iniciar
│   ├── pbi-01-requisitos-previos.md   Las 6 herramientas + prerrequisitos del equipo y del proyecto
│   ├── pbi-02-matriz-responsabilidades.md   Qué herramienta hace cada operación (verificada)
│   ├── pbi-03-nube-vs-local.md        Local por defecto; la nube siempre se pregunta
│   ├── pbi-04-seguridad-y-vigencia.md Qué es "vigente" y "segura"; instalación segura
│   └── pbi-05-formato-pbip.md         PBIP (no PBIX) como formato de trabajo; conversión caso por caso
├── skills/
│   ├── pbi-preflight/                 /pbi-preflight: verificar e instalar requisitos
│   ├── pbi-convertir-pbip/            /pbi-convertir-pbip: respaldo, conversión guiada y verificación
│   ├── pbi-nube/                      /pbi-nube: protocolo antes de tocar la nube
│   └── pbi-verificar-docs/            /pbi-verificar-docs: revalidar contra la doc oficial
├── hooks/
│   ├── session-start.ps1              Verificación única al iniciar la sesión (caché de 24 h)
│   └── guard-nube.ps1                 Pide confirmación ante comandos o MCP de nube
├── scripts/
│   ├── pbi-preflight.ps1              Comprobaciones (solo lectura)
│   ├── pbi-formato.ps1                Inventario / respaldo / verificación del formato PBIP
│   └── pbi-nube.ps1                   Aprobación temporal de la nube (aprobar / revocar / estado)
└── pbi/
    ├── herramientas.json              Manifiesto: versiones, orígenes de confianza, patrones de nube, fuentes
    ├── verificacion-documental.md     Informe de la verificación contra la documentación + historial
    └── estado/                        (generado, no versionado) preflight.json, nube-aprobada.json
```

## Usarla en un proyecto

1. Copia la carpeta a la raíz del proyecto:
   ```powershell
   Copy-Item -Recurse "D:\ninchaustegui\Desktop\PWOERBI_REGLAS\.claude" "<ruta del proyecto>\"
   ```
   Si el proyecto ya tiene `.claude/settings.json`, **fusiona** las secciones `permissions` y `hooks` en lugar de sobrescribir. Copia la carpeta sin `pbi/estado/`.
2. Abre Claude Code en la raíz del proyecto y acepta la confianza de la carpeta, para que se carguen los hooks.
3. Al iniciar verás `Preflight Power BI: OK | AVISOS | BLOQUEADO`. Si no es OK, ejecuta `/pbi-preflight`.

## Cómo funciona

| Momento | Qué pasa | Mecanismo |
|---|---|---|
| Inicio de sesión | Verifica requisitos (local + vigencia en registros públicos) y revoca aprobaciones de nube anteriores | Hook `SessionStart` |
| Antes de trabajar | Si hay bloqueantes, Claude no empieza tareas de Power BI y propone `/pbi-preflight` | `CLAUDE.md` + contexto del hook |
| Instalación | Plan, una confirmación, versiones exactas, reinicio y nueva verificación | Skill `/pbi-preflight` |
| Formato | Detecta PBIX/PBIT o formatos antiguos; convierte solo si la tarea lo requiere (respaldo, Desktop *Guardar como*, verificación, commit) | Skill `/pbi-convertir-pbip` + regla `pbi-05` |
| Cada comando o llamada MCP | Si toca la nube sin aprobación vigente, pide confirmación | Hook `PreToolUse` + `permissions.ask` |
| Nube | Pregunta: lo hace Claude / da los pasos / sigue en local | Skill `/pbi-nube` |
| Cambios de Microsoft | Detecta cambios en Learn o en el manifiesto del plugin y propone actualizar reglas y matriz | Preflight + `/pbi-verificar-docs` |

## Notas

- **Windows PowerShell 5.1** ejecuta los scripts, que funcionan igual si Claude Code lanza los hooks con Git Bash o con PowerShell. Los `.ps1` están en ASCII a propósito, para que 5.1 no estropee los caracteres.
- El hook `guard-nube` se ejecuta antes de cada comando de shell y añade unos 0,5 s.
- **Modo bypass**: las reglas `permissions.ask` siguen preguntando también en bypass. El resto de la política depende del hook y de las reglas.
- **Sin red**: define `PBI_PREFLIGHT_OFFLINE=1` o pon `politica.verificacionEnLinea` en `false`. Solo se comprobará lo local.
- **Actualizar la plantilla**: ejecuta `/pbi-verificar-docs` en este directorio y vuelve a copiarla a los proyectos.
