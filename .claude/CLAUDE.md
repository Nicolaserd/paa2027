# Proyecto Power BI — reglas base

Esta carpeta `.claude/` es una plantilla general para cualquier proyecto de Power BI.
Define qué debe estar instalado y verificado **antes** de empezar, cómo se reparte el
trabajo entre las herramientas oficiales de Microsoft y cuándo se puede tocar la nube.

## Puerta de entrada (obligatoria)

1. Al abrir la sesión, el hook `SessionStart` ejecuta la verificación de requisitos
   (`.claude/scripts/pbi-preflight.ps1`) y guarda el resultado en `.claude/pbi/estado/preflight.json`.
   Si el último resultado fue OK hace menos de 24 h, no la repite.
2. Si el resultado es **BLOQUEADO**, no empieces ninguna tarea de Power BI (modelo, DAX,
   reportes, publicación). Informa los pendientes y ejecuta el skill `/pbi-preflight`.
3. Si es **AVISOS**, infórmalos al inicio y ofrece `/pbi-preflight`; se puede trabajar en
   local si el usuario lo acepta.
4. Nunca rodees la puerta con otras herramientas (pbi-cli, edición manual de TMDL/PBIR,
   scripts propios) salvo que el usuario lo autorice de forma explícita.
5. **El formato de trabajo es PBIP** (informe PBIR y modelo TMDL), no PBIX. Si la tarea lo
   requiere y el proyecto solo tiene un `.pbix` o `.pbit`, o formatos antiguos, ejecuta
   `/pbi-convertir-pbip` antes de empezar (regla `pbi-05`).

## Reglas detalladas (se cargan solas desde `.claude/rules/`)

- `pbi-01-requisitos-previos.md`: las 6 herramientas y los prerrequisitos del equipo y del proyecto.
- `pbi-02-matriz-responsabilidades.md`: qué herramienta hace cada operación (verificada con la documentación oficial).
- `pbi-03-nube-vs-local.md`: local por defecto; la nube siempre se pregunta antes.
- `pbi-04-seguridad-y-vigencia.md`: criterios de "vigente" y "segura", e instalación segura.
- `pbi-05-formato-pbip.md`: PBIP como formato de trabajo y cuándo y cómo convertir, caso por caso.

## Skills del proyecto

- `/pbi-preflight`: verifica, informa y (con confirmación) instala o actualiza los requisitos locales.
- `/pbi-convertir-pbip`: inventario, respaldo, conversión guiada en Desktop y verificación del formato PBIP.
- `/pbi-nube`: protocolo obligatorio antes de cualquier conexión a Power BI Service, Fabric o Entra ID.
- `/pbi-verificar-docs`: vuelve a leer la documentación oficial y actualiza reglas, matriz y manifiesto si algo cambió.

## Fuente de verdad

- Requisitos, versiones verificadas, orígenes de confianza, patrones de nube y fuentes oficiales: `.claude/pbi/herramientas.json`.
- Informe de la última verificación documental: `.claude/pbi/verificacion-documental.md`.
- Ninguno de estos archivos se modifica sin pasar por `/pbi-verificar-docs` y sin la confirmación del usuario.
