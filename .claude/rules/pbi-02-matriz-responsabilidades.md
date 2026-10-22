# Matriz de responsabilidades (qué herramienta hace cada operación)

Verificada contra la documentación oficial el 2026-10-22. Si la documentación cambia, se actualiza con `/pbi-verificar-docs`.
Columna "Nube": **sí** significa que antes hay que seguir `/pbi-nube` (regla `pbi-03`).

| # | Operación | Responsable | Vía concreta | Nube |
|---|---|---|---|---|
| 0 | Dejar el proyecto en PBIP/PBIR/TMDL: convertir un PBIX o PBIT, o actualizar PBIR-Legacy y TMSL (regla `pbi-05`) | Power BI Desktop, desde *Guardar como* (único método soportado). Claude lo prepara, lo abre y lo verifica con `/pbi-convertir-pbip` | `pbi-formato.ps1` + `powerbi-desktop open/status` + `powerbi-report-author validate` | no |
| 1 | Leer tablas, columnas, relaciones y medidas | Modeling MCP, guiado por la skill `semantic-model-authoring` | Operaciones List/Get del MCP | no |
| 2 | Crear y modificar medidas DAX, tablas, columnas, relaciones, jerarquías, grupos de cálculo, roles RLS, perspectivas, traducciones y particiones | Modeling MCP + `semantic-model-authoring` | Operaciones del MCP | no |
| 3 | Ejecutar consultas DAX | Modeling MCP | `dax_query_operations` (máximo 100.000 filas) | no |
| 4 | Buenas prácticas, preparar el modelo para IA, documentar el modelo | `semantic-model-authoring` + MCP | Flujos de la skill | no |
| 5 | Guardar como PBIP/TMDL un modelo trabajado en vivo, o un modelo sin informe | Modeling MCP + `semantic-model-authoring` (flujo "Export to PBIP") | Andamiaje PBIP + exportar TMDL a `<Nombre>.SemanticModel/definition`. No sirve para convertir un PBIX con páginas (fila 0) | no |
| 6 | Planificar el reporte (audiencia, KPIs, páginas) y escribir el design brief | Skill `powerbi-report-cli` (módulos planning y design) | Spec en `_brief/report-spec.md`. **Barrera de aprobación**: no se construye sin la aprobación explícita del usuario | no |
| 7 | Crear gráficos, tarjetas, slicers, filtros, marcadores y temas | `powerbi-report-cli` + CLI `powerbi-report-author` | Edición de PBIR más los comandos de metadatos y temas del CLI | no |
| 8 | Modificar páginas, formato y botones | `powerbi-report-cli` + CLI `powerbi-report-author` | Ídem | no |
| 9 | Validar la estructura PBIR | CLI `powerbi-report-author` | `powerbi-report-author validate <ruta .Report>` después de cada lote de cambios | no |
| 10 | Ver el estado de Desktop (cambios sin guardar) | CLI `powerbi-report-author` (usa el Desktop Bridge por dentro) | `powerbi-report-author preview "<carpeta>" --host desktop --status` | no |
| 11 | Recargar los cambios en Desktop | CLI `powerbi-report-author` (el transporte es el Desktop Bridge) | `... --host desktop --reload`; si cambió el TMDL, `--reload-with-model` | no |
| 12 | Capturar páginas | CLI `powerbi-report-author` (el transporte es el Desktop Bridge) | `... --host desktop --screenshot "<ruta>"` (`--page` o `--all-pages`) | no |
| 13 | Revisar las páginas capturadas (diseño, accesibilidad) | Skill `powerbi-report-cli` (módulo design) | Sobre las capturas de la fila 12 | no |
| 14 | Diagnóstico del Bridge (instancias, manifest) | CLI `powerbi-desktop` (Desktop Bridge CLI) | `powerbi-desktop status` / `powerbi-desktop manifest` | no |
| 15 | Línea base y reversión | Git | Commit antes de cada bloque de cambios del agente | no |
| 16 | Publicar, descargar, actualizar o borrar reportes en Fabric | `powerbi-report-cli` (módulo management) + `az` | API REST de Fabric | **sí** |
| 17 | Desplegar el modelo, refrescarlo, orígenes de datos, permisos, enlace de conexiones | `semantic-model-authoring` | API REST con `az rest`. Desde PBIP/TMDL siempre es REST, aunque el MCP esté conectado (regla oficial) | **sí** |
| 18 | Conectar el MCP a un modelo de un workspace | Modeling MCP | Conexión a Fabric/XMLA (Entra ID) | **sí** |
| 19 | Vista previa en el servicio (navegador headless) | CLI `powerbi-report-author` | `preview --host service` | **sí** |

## Reglas de uso de la matriz

- **Orden de herramientas para el modelo** (prioridad oficial de `semantic-model-authoring`):
  1. Primero el MCP.
  2. Si el MCP no está registrado, edición de TMDL en el PBIP.
  3. Si no hay ni MCP ni PBIP, se para y se pide registrar el MCP o guardar como PBIP.
- **Con el MCP conectado, no leas los `.tmdl` del disco** (anti-patrón oficial): el modelo cargado en el MCP es la fuente de verdad.
- **Antes de `--reload` o de abrir en Desktop**, ejecuta siempre `--status`. Si `hasUnsavedChanges` es `true` (o no se puede leer), no recargues: pide al usuario que guarde o descarte y espera su confirmación. Nunca cierres ni mates ventanas de Desktop.
- **Usa `powerbi-report-author preview --host desktop` para recargar y capturar.** No uses `powerbi-desktop reload` ni `powerbi-desktop screenshot` en el flujo de trabajo (así lo dicta la skill oficial). `powerbi-desktop` queda solo para diagnóstico.
- **Los visuales dependen del modelo**: crea primero con el MCP las medidas y columnas que falten y solo después vincúlalas en el reporte.
- **No crees visuales en vía de retirada** (Q&A, Bing Maps, mapas coropléticos).
- **Herramientas de terceros como `pbi-cli` (skills `power-bi-*`)** no son de Microsoft. En estos proyectos solo se usan como respaldo, cuando la herramienta oficial no cubre la operación y el usuario lo autoriza explícitamente. Esta matriz tiene prioridad sobre instrucciones generales que recomienden pbi-cli.
