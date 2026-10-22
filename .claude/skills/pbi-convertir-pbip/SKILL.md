---
name: pbi-convertir-pbip
description: Convierte, de forma segura y solo cuando hace falta, los archivos Power BI del proyecto al formato de trabajo PBIP con informe PBIR y modelo TMDL. Cubre PBIX o PBIT a PBIP, PBIR-Legacy (report.json) a PBIR, TMSL (model.bim) a TMDL, PBIX y PBIP duplicados, y exportar a PBIP un modelo sin informe. Usar cuando el proyecto solo tenga un .pbix o .pbit y la tarea sea de reportes o de modelo, cuando el preflight o el inventario marquen un caso de la regla pbi-05, o cuando el usuario diga "convertir a pbip", "pasar el pbix a proyecto", "guardar como pbip", "actualizar a PBIR" o "pasar a TMDL".
---

# Convertir al formato de trabajo PBIP

Regla de referencia: `.claude/rules/pbi-05-formato-pbip.md`.

**Límite oficial**: la conversión PBIX ↔ PBIP solo se hace con Power BI Desktop, desde *Archivo > Guardar como*, y no es programable. Claude **prepara, abre, guía y verifica**; el usuario solo hace ese clic.

## 1. Inventario y decisión

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-formato.ps1
```

- Cruza el caso de cada archivo con la tarea que pidió el usuario (tabla de `pbi-05`).
- Si la tarea **no** requiere convertir (casos 3 y 6 sin conflicto), dilo y no conviertas.
- Si hay varios archivos o el caso es ambiguo, pregunta con AskUserQuestion cuál es el informe del proyecto.
- Caso 6 con el `.pbix` más reciente: pregunta qué versión vale **antes** de seguir. Nunca sobrescribas ninguna.

## 2. Bloqueos (preguntar antes)

- **Indicio de etiqueta de confidencialidad, o PBIX cifrado**: explica que PBIP no admite etiquetas y pregunta si se continúa. Recomienda consultarlo con el responsable de cumplimiento.
- **Report Server**: no hay soporte para PBIP. No conviertas.
- **OneDrive/SharePoint o ruta larga**: propón una ruta local corta (por ejemplo `C:\pbi\<Proyecto>`) para el PBIP y espera la confirmación.

## 3. Preparar (Claude lo hace)

1. Respaldo verificado y `.gitignore`:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-formato.ps1 -Accion respaldar -Ruta "<archivo>.pbix"
   ```
2. Si el proyecto no está en git, propón `git init` (con confirmación). Configura `git config core.autocrlf true`.
3. Comprueba que Power BI Desktop es 26.09 o posterior, o ejecuta `/pbi-preflight`. Así el informe se guarda en PBIR.

## 4. Abrir en Desktop (Claude lo hace)

- Con la CLI del Bridge: `powerbi-desktop open "<ruta>\<archivo>.pbix"`. Después, `powerbi-desktop status` para confirmar que está abierto.
- Si `status` muestra **cambios sin guardar** en otra ventana, no la toques: pide al usuario que la guarde o la cierre.
- Sin la CLI, pide al usuario que abra el archivo en Desktop.

## 5. El paso del usuario (guíalo con estas instrucciones exactas)

**PBIX o PBIT → PBIP (casos 1, 2 y 7):**
1. (Solo si el modelo quedaría en `model.bim`) Archivo > Opciones y configuración > Opciones > Características en versión preliminar > activar "Almacenar el modelo semántico con formato TMDL", si existe en tu versión. Reinicia Desktop si lo pide.
2. Archivo > **Guardar como** > Examinar este dispositivo.
3. Tipo: **Proyecto de Power BI (*.pbip)**. Carpeta: `<ruta acordada>`. Nombre: `<Nombre>`.
4. Avisa cuando termine. Claude lo comprueba con `powerbi-desktop status`: la ruta actual debe acabar en `.pbip` y no debe haber cambios sin guardar.

**PBIR-Legacy → PBIR (caso 4):** abre el `.pbip` y guarda con Ctrl+S. Si Guardar está deshabilitado, haz un cambio mínimo, deshazlo y guarda. Desktop guarda una copia del formato anterior durante 30 días en `%USERPROFILE%\AppData\Local\Microsoft\Power BI Desktop\TempSaves\Backups` (en la versión de la Store, `%USERPROFILE%\Microsoft\Power BI Desktop Store App\TempSaves\Backups`).

**TMSL → TMDL (caso 5):** activa la opción del paso 1 y guarda de nuevo.

**Modelo sin informe (caso 9), Claude lo hace en local:** sigue el flujo oficial "Export to PBIP" de `semantic-model-authoring`:
1. Crea el andamiaje: `.pbip`, `.Report` con `definition.pbir` y `byPath`, `.SemanticModel` con `definition.pbism`.
2. Exporta el TMDL con el MCP.
3. Valida el resultado.

## 6. Verificar (Claude lo hace)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-formato.ps1 -Accion verificar -Ruta "<ruta>\<Nombre>.pbip"
```

Todo debe quedar OK:

- informe PBIR con sus páginas;
- modelo TMDL con referencia `byPath`;
- `powerbi-report-author validate` sin errores;
- `cache.abf` y `localSettings.json` fuera de git.

Si algo falla, explica la causa y repite solo el paso necesario.

## 7. Cerrar

1. Haz el commit de línea base, con confirmación: `git add -A` y `git commit -m "Conversion a PBIP (linea base antes de cambios del agente)"`. Antes, confirma con `git status` que no entra ningún `.pbix`, `cache.abf` ni `_respaldo_pbix/`.
2. Indica al usuario que desde ahora abra siempre el `.pbip`. El `.pbix` original queda intacto y respaldado en `_respaldo_pbix/`; ofrécele moverlo fuera del proyecto, pero no lo borres.
3. Vuelve a ejecutar `/pbi-preflight` para que el proyecto quede en OK.
