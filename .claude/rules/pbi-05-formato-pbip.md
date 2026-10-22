# Formato de trabajo: PBIP (no PBIX)

Verificado con la documentación oficial el 2026-10-22 (fuentes en `.claude/pbi/verificacion-documental.md`, sección 4).

## Lo que dice Microsoft

- **Reportes**: la autoría local requiere **PBIP con informe en PBIR**. La recarga y las capturas en Desktop trabajan sobre el PBIR del disco y necesitan el `.pbip`.
- **Modelo**:
  - El MCP puede conectarse en vivo a un `.pbix` abierto en Desktop.
  - Sin PBIP no hay archivos de texto, así que no hay diff ni reversión con git.
  - Sin MCP y sin PBIP, la skill oficial se detiene y pide guardar como PBIP.
- **Conversión**: PBIX ↔ PBIP **solo** se puede hacer con Power BI Desktop, desde *Archivo > Guardar como*. La FAQ oficial dice que no es programable. Nunca la simules con scripts, ZIP ni herramientas de terceros.
- **PBIR** es el formato de informe por defecto (GA). Al editar y guardar un informe PBIR-Legacy con Desktop 26.09 o posterior, se convierte solo a PBIR y Desktop guarda una copia durante 30 días.
- **TMDL**: si el modelo queda como `model.bim` (TMSL), hay que guardarlo en TMDL con la opción de vista previa de Desktop "Almacenar el modelo semántico con formato TMDL", si existe en esa versión.

## Decisión por caso: convertir solo cuando es necesario

El inventario de `.claude/scripts/pbi-formato.ps1` indica el caso de cada archivo.

| Caso | Situación | ¿Convertir? | Qué hace Claude |
|---|---|---|---|
| 1 | Solo `.pbix`, y la tarea es de **reporte** (visuales, páginas, formato, validar, recargar, capturar) | **Sí, obligatorio** | `/pbi-convertir-pbip` antes de empezar |
| 2 | Solo `.pbix`, y la tarea es de **modelo** (medidas, relaciones, RLS…) | **Sí, recomendado** | `/pbi-convertir-pbip`. Solo si el usuario lo pide expresamente: MCP en vivo sobre Desktop, con respaldo previo del `.pbix` y avisando de que no habrá diff |
| 3 | Solo `.pbix`, y la tarea es de **solo lectura** (consultas DAX, documentar, inventario) | No | Conectar el MCP a Desktop con el `.pbix` abierto |
| 4 | `.pbip` con informe en PBIR-Legacy (`report.json`) | Sí (formato) | Abrir en Desktop ≥ 26.09 y guardar; luego verificar |
| 5 | `.pbip` con modelo en TMSL (`model.bim`) | Sí (formato) | Activar TMDL en Desktop y guardar; luego verificar |
| 6 | `.pbix` y `.pbip` del mismo informe | No | El PBIP es la fuente de verdad. Si el `.pbix` es más reciente, preguntar cuál vale. Nunca sobrescribir ninguno |
| 7 | Plantilla `.pbit` | Solo si se va a desarrollar a partir de ella | Abrirla en Desktop y *Guardar como* PBIP |
| 8 | Informe conectado en vivo a un modelo del servicio (`byConnection`) | El informe sí; el modelo está en la nube | Trabajar el informe en local. Cualquier cambio del modelo pasa por `/pbi-nube` |
| 9 | Modelo sin informe, creado o cargado con el MCP | Exportar, no convertir | Flujo oficial "Export to PBIP" de `semantic-model-authoring` (andamiaje + exportar TMDL). **Nunca** para un `.pbix` con páginas, porque el informe se perdería |
| 10 | Hay que entregar un `.pbix` (enviarlo, Report Server) | PBIP → PBIX solo si el usuario lo pide | Desktop: *Guardar como* `.pbix`. El PBIP sigue siendo la fuente |

## Preguntar antes de convertir (bloqueos)

- **Etiqueta de confidencialidad** en el `.pbix`: los proyectos PBIP no admiten etiquetas. Pregunta y propón consultarlo con el responsable de cumplimiento. El inventario detecta indicios; confírmalo en Desktop.
- **Power BI Report Server**: la versión de Desktop para Report Server no admite PBIP.
- **Sinónimos lingüísticos** (Linguistic Schema): no se conservan en PBIP.
- **Carpeta de OneDrive o SharePoint, o ruta larga**: guarda el PBIP en una ruta local corta (límite de 260 caracteres).

## Garantías obligatorias al convertir

1. **Respaldo verificado** del archivo original antes de tocar nada (`pbi-formato.ps1 -Accion respaldar`). El `.pbix` original nunca se borra ni se sobrescribe.
2. **`.gitignore` preparado antes de guardar**: Desktop solo crea su `.gitignore` si no existe uno. Debe excluir:
   - `**/.pbi/cache.abf` (contiene **datos**);
   - `**/.pbi/localSettings.json`;
   - `_respaldo_pbix/`;
   - `*.pbix`.
3. **Verificación** con `pbi-formato.ps1 -Accion verificar`: comprueba PBIR, TMDL y `byPath`, ejecuta `powerbi-report-author validate` y confirma que `cache.abf` queda fuera de git.
4. **Git**: `core.autocrlf true` (recomendación oficial) y un **commit de línea base** justo después de convertir, antes de cualquier cambio del agente.
5. **Privacidad**: algunos archivos PBIR (por ejemplo `visual.json` con filtros o selecciones de slicer) guardan valores de datos. Revísalos antes de publicar el repositorio.
6. **Desde ese momento se abre siempre el `.pbip`**, no el `.pbix`.
7. Los archivos editados fuera de Desktop se guardan en UTF-8 sin BOM.
