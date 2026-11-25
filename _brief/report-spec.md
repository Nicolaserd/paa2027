# Report Spec — Líneas del PAA 2027

> **Revisión 2 (vigente, 2026-11-25).** Cambios pedidos por el usuario después de aprobar la versión 1. Prevalecen sobre las secciones y el YAML de abajo, que quedan como historial de la versión 1:
>
> - **Páginas**: Portada + **una sola página "Tablero PAA 2027"** de 1920 × 2072, en modo "Ajustar al ancho" con desplazamiento vertical. Se eliminan las páginas Estadísticas, Detalle (drillthrough) y Vista rápida (tooltip).
>   - Bloque superior: cabecera con botón Portada, buscador de texto en la descripción, filtros Solicitante, Tipo de necesidad y Etapa, y Limpiar filtros; franja de 6 KPIs; tabla dominante (1240 × 828); gráficas de valor por mes, líneas por etapa y valor por tipo de necesidad.
>   - Bloque inferior: 6 KPIs de concentración; top 10 dependencias; segmento UNSPSC; fuente de recursos; **número de líneas y % del valor por rango de valor** (reemplaza la dispersión valor–duración, que no se entendía); valor por unidad de contratación.
> - **Tabla**: exactamente las 6 columnas con encabezado coloreado del Excel, en su orden: Identificador, Tipo de necesidad, Descripción de la necesidad, Valor total de la necesidad (con barras de datos), Nombre del solicitante y Fecha estimada de inicio del proceso (mes). Sin columnas SVG.
> - **Colores**: sin amarillo ni dorado. Verde institucional #00482B, oliva #8B7D36 (listón del escudo), salvia #D7E6DD / #A9C4B6, gris #4D4D4D, azul #2C7DA0 y rojo #B3121A solo para la etapa "Ajuste solicitado". El escudo oficial conserva sus colores.
> - **Ejes**: todas las gráficas cartesianas muestran el nombre de sus ejes.
> - **Modelo**: nuevas columnas `Rango de valor` y `Orden de rango de valor` (desde el ETL). Se eliminan las medidas de ficha y las medidas SVG, que ya no se usan.
> - **Animaciones**: fondo y emblema SVG animados en la portada, más las transiciones nativas de Power BI al filtrar.

## Report identity
- Report name: Lineas PAA 2027
- Semantic model: Lineas PAA 2027 (nuevo, Import desde `data/paa_lineas.csv`)
- Audience: Administrador del PAA, Comité de Contratación y directivos de planeación de la Universidad de Cundinamarca (inferido; ajustable)
- Primary purpose: revisar línea por línea las necesidades nuevas del PAA 2027 (qué se pide, quién lo pide, cuánto vale, cuándo inicia y en qué etapa del flujo va) y ver dónde se concentra el valor
- Delivery target: PBIP local solamente (sin publicar; la nube pasa por `/pbi-nube`)

## Semantic model binding
- Entry mode:          No Model → se crea con `semantic-model-authoring` + Modeling MCP y luego se trabaja como Local Model
- Model name:          Lineas PAA 2027
- connectionString:    byPath `../Lineas PAA 2027.SemanticModel`

## User decisions and constraints
- Scope: portada animada + tablero con tabla dominante + página de estadísticas + detalle (drillthrough) + tooltip de fila
- Page count: 3 visibles (Portada, Tablero, Estadísticas) + 2 ocultas (Detalle, Vista rápida)
- Interactivity:
  - Navegación: navegador de páginas en la cabecera de Tablero y Estadísticas; botón "Explorar las líneas" en la portada; botón "Volver" en Detalle.
  - Acciones de botón: navegación de páginas, Back, "Limpiar filtros" (ClearAllSlicers).
  - Drillthrough: clic derecho en una fila → "Detalle de la necesidad" por `Identificador`.
  - Tooltip de página al pasar el cursor por una fila de la tabla.
  - Segmentadores (desplegables con búsqueda): Solicitante, Tipo de necesidad, Etapa; sincronizados entre Tablero y Estadísticas.
  - Filtro cruzado: los gráficos del Tablero filtran la tabla al hacer clic.
- Design direction: identidad visual UCundinamarca 2026 (carpeta `NUEVA IMAGEN UCUNDINAMARCA 2026`): verde institucional, amarillo y dorado del escudo, logos oficiales en PNG.
- Animaciones (lo que Power BI permite de forma nativa, sin visuales de terceros):
  1. Portada: emblema SVG animado (estrella del escudo que gira, anillos que se dibujan y contorno de Cundinamarca trazándose con los colores rojo, azul y amarillo).
  2. Tabla: barra de valor SVG por fila que crece al cargar o filtrar, e insignia de etapa con pulso en "Ajuste solicitado".
  3. Botones con estados al pasar el cursor y al presionar; transiciones nativas de los gráficos al filtrar.
- Columnas de referencia (encabezados coloreados en verde en el Excel): Identificador, Tipo de Necesidad, Descripción de la Necesidad, Valor Total, Nombre del solicitante, Fecha Estimada de Inicio del Proceso (mes). Son las columnas principales de la tabla, en ese orden, con encabezado verde.
- Publishing: no
- Tooling: Modeling MCP (modelo), `powerbi-report-author` 0.5.0 (PBIR, validate, preview), Power BI Desktop 26.09
- Model edit permissions: modelo nuevo y local
- Accessibility: contraste AA en textos, texto alternativo en cada gráfico, el amarillo solo como relleno o sobre verde
- Data caveats:
  - "Fecha Estimada de Inicio del Proceso" (mes, columna L) difiere del mes de "Fecha estimada de inicio del proceso de contratación" (columna F) en 71 líneas: se conservan ambas. La tabla usa la de referencia (mes del proceso); el calendario usa la fecha de contratación.
  - 31 líneas sin unidad de contratación → "Sin asignar".
  - Estado, modalidad y vigencias futuras tienen hoy un solo valor; se conservan para futuras versiones del archivo.
  - Se descartan: teléfono y correo del responsable, fecha de creación y número de proyecto (vacíos o constantes).
  - Actualización: ejecutar `etl/preparar_datos_paa.py` con el nuevo .xls y luego Actualizar en Desktop.

## Narrative
- Core story: 311 necesidades nuevas por unos COP 42.279 millones; la mayoría es contratación de personal y arranca en enero–febrero; cada línea avanza por revisión → ajuste → comité.
- Audience promise: encontrar cualquier línea en segundos, ver su valor relativo y saber en qué etapa está.
- Key questions answered:
  - ¿Qué líneas hay, de quién son, cuánto valen y cuándo inician?
  - ¿Cuántas están listas para comité y cuántas requieren ajuste?
  - ¿Qué dependencias, tipos de necesidad, segmentos UNSPSC y fuentes concentran el valor?
  - ¿Qué tan concentrado está el arranque en el primer trimestre?

## Design identity
- Tone: Institucional UCundinamarca — verde profundo con acentos amarillo y dorado, sobrio y legible
- Signature: franja de cabecera verde con escudo + barras de valor SVG animadas dentro de la tabla
- Brownfield delta: n/a (greenfield)

## Page plan
1. Portada — "Líneas del PAA 2027"
   - Archetype: Narrative (landing). Layout variant: A (emblema a la derecha, título y KPIs a la izquierda)
   - Purpose: presentar el informe y sus cifras clave
   - Visuals: fondo verde, logo horizontal blanco de alta calidad, emblema SVG animado, título y subtítulo, tarjeta con 4 KPIs, botones "Explorar las líneas" y "Ver estadísticas", nota de fuente
2. Tablero — "Líneas del PAA 2027 por necesidad"
   - Archetype: Analytical Canvas. Layout variant: B (tabla dominante a la izquierda, columna de gráficos a la derecha)
   - Purpose: explorar línea por línea (la tabla ocupa ~61 % del área de contenido)
   - Visuals: franja de 6 KPIs; tabla con las 6 columnas de referencia + barra SVG + insignia de etapa; gráficos: valor por mes de inicio del proceso, líneas por etapa, valor por tipo de necesidad
   - Slicers/interactions: Solicitante, Tipo de necesidad, Etapa (desplegables) + Limpiar filtros; drillthrough y tooltip en la tabla
3. Estadísticas — "¿Dónde se concentra el valor del PAA 2027?"
   - Archetype: Executive Summary / Comparative. Layout variant: A
   - Visuals: 6 KPIs de contexto (personal, primer trimestre, top 5 dependencias, duración, máximo, sin unidad); valor y líneas por mes (combinado); valor por segmento UNSPSC; top 10 dependencias; fuente de recursos (anillo); valor frente a duración por línea (dispersión)
4. Detalle de la necesidad (drillthrough, oculta)
   - Visuals: tarjeta de datos clave; descripción; justificación completa; botón Volver
5. Vista rápida de la línea (tooltip, oculta, 480×320)
   - Visuals: identificador, valor, solicitante, etapa y descripción

## Design system summary
- Theme: "UCundinamarca PAA", basado en `base.json` del skill. Paleta: #00482B, #DAAA00, #48C7F4, #4D4D4D, #8B7D36, #B3121A, #7FA393, #FBE122
- Color semantics: Valor → verde #00482B; Líneas → dorado #DAAA00; Etapa: En revisión #2C7DA0, Ajuste solicitado #B3121A, Para comité #00482B
- Typography: Segoe UI Semibold (títulos y cifras) + Segoe UI (cuerpo); números tabulares
- Layout: lienzo 1920×1080, margen 32, separación 24, cuadrícula 12×12; cabecera verde de una fila en páginas de análisis
- Accessibility: blanco sobre verde (contraste 10,9:1); texto oscuro sobre amarillo; alt text en gráficos; orden de tabulación de arriba abajo

## Model requirements
- Tablas:
  - `Líneas PAA` (hecho, una fila por línea, 311 filas): partición M que lee `paa_lineas.csv` desde el parámetro `Carpeta de datos`.
  - `Calendario` (M, 2026-01-01 a 2028-12-31, marcada como tabla de fechas).
- Relación: `Líneas PAA`[Fecha estimada de contratación] (muchos) → `Calendario`[Fecha] (uno), dirección única. El resto de dimensiones queda desnormalizado en la tabla de hechos porque el origen es una sola lista de 311 filas.
- Columnas ocultas: Número de línea (orden de Identificador), Número de mes del proceso (orden del mes), Orden de etapa, Valor de la necesidad, Duración en meses, la fecha clave.
- Cultura del modelo: es-CO. Se desactivan las medidas implícitas.
- Medidas nuevas (con formato y descripción):
  - Indicadores: Líneas PAA, Valor total PAA, Valor promedio por línea, Valor máximo de una línea, Dependencias solicitantes, Duración promedio (meses), % del valor total
  - Flujo: Líneas en revisión, Líneas con ajuste solicitado, Líneas para comité, % líneas listas para comité
  - Concentración: % valor contratación de personal, % valor primer trimestre, % valor top 5 dependencias, Líneas sin unidad de contratación
  - Visuales SVG: Barra de valor SVG, Etapa SVG (categoría ImageUrl)
- Sin columnas calculadas (toda la preparación está en `etl/preparar_datos_paa.py` y en M).

## Canonical design contract

```yaml
Design Brief:
  generated_by: powerbi-report-cli
  contract_version: 1
  mode: greenfield
  design_identity:
    tone: "Institucional UCundinamarca: verde profundo #00482B con acentos amarillo #FBE122 y dorado #DAAA00, fondo claro #F4F6F3, densidad media-alta"
    signature: "Franja de cabecera verde con escudo y barras de valor SVG animadas dentro de la tabla"
  archetype: Analytical Canvas
  navigation_model: page_navigator
  color_map:
    - measure: "'Líneas PAA'[Valor total PAA]"
      color: "#00482B"
      tint: "#DCE9E2"
    - measure: "'Líneas PAA'[Líneas PAA]"
      color: "#DAAA00"
      tint: "#FBF3D1"
    - measure: "'Líneas PAA'[Duración promedio (meses)]"
      color: "#2C7DA0"
      tint: "#DDEFF6"
  pages:
    - name: "Portada"
      role: landing
      archetype: Narrative
      layout_variant: A
      variant_rationale: "La portada presenta el informe: el emblema animado ancla la marca y las cifras clave invitan a entrar."
      navigation:
        - element: button
          action: PageNavigation
          target: "Tablero"
          label: "Explorar las líneas"
        - element: button
          action: PageNavigation
          target: "Estadísticas"
          label: "Ver estadísticas"
      page_background: "#00482B"
      layout_summary: "Fondo verde a sangre con textura SVG; franja superior con logo; título grande, KPIs y botones a la izquierda; emblema animado a la derecha; nota de fuente abajo."
      layout_contract:
        canvas: { width: 1920, height: 1080, margin: 32, gutter: 24, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            bg_hero:   [1, 1, 13, 13]
            brand_bar: [1, 1, 13, 2]
            header:    [1, 3, 8, 6]
            kpis:      [1, 6, 8, 9]
            cta:       [1, 9, 8, 11]
            emblem:    [8, 2, 13, 12]
            footer:    [1, 12, 13, 13]
        placements:
          - id: bg_texture
            region: bg_hero
            kind: image
            purpose: "Textura de fondo SVG (estructura, sin datos)"
          - id: logo_horizontal
            region: brand_bar
            kind: image
            purpose: "Logo oficial 'ALTA CALIDAD HORIZONTAL BLANCO'"
          - id: page_title
            region: header
            kind: textbox
            text: "Líneas del PAA 2027"
            purpose: "Título de la portada"
            slot: 1
            of: 2
          - id: subtitle
            region: header
            kind: textbox
            text: "Plan Anual de Adquisiciones · Necesidades nuevas · Universidad de Cundinamarca"
            slot: 2
            of: 2
          - id: cover_kpis
            region: kpis
            kind: cardVisual
            purpose: "¿Cuántas líneas hay, cuánto suman, cuántas dependencias y qué tan avanzadas están?"
            field_bindings: ["'Líneas PAA'[Líneas PAA]", "'Líneas PAA'[Valor total PAA]", "'Líneas PAA'[Dependencias solicitantes]", "'Líneas PAA'[% líneas listas para comité]"]
            insight_basis: "Cifras de entrada; el % para comité aporta avance del flujo"
            color_strategy: none
          - id: btn_explorar
            region: cta
            kind: actionButton
            text: "Explorar las líneas"
            slot: 1
            of: 2
          - id: btn_estadisticas
            region: cta
            kind: actionButton
            text: "Ver estadísticas"
            slot: 2
            of: 2
          - id: emblem_animado
            region: emblem
            kind: image
            purpose: "Emblema SVG animado (estrella del escudo, anillos y contorno de Cundinamarca)"
          - id: source_note
            region: footer
            kind: textbox
            text: "Fuente: LINEAS NUEVAS PAA 2027 (exportación del sistema PAA). Valores en pesos colombianos."
        space_audit:
          content_cell_count: 132
          placed_cell_count: 118
          empty_cell_pct: 11
          unplaced_regions: []
          largest_region: { name: emblem, pct_of_content: 38 }
          balance_rationale: "Portada narrativa: el emblema animado es el ancla de marca y el bloque izquierdo concentra título, cifras y acciones; solo quedan dos bandas de una fila como respiro."
    - name: "Tablero"
      role: detail
      archetype: Analytical
      layout_variant: B
      variant_rationale: "El usuario pidió que la tabla ocupe la mayor parte de la pantalla; los gráficos de la derecha sirven de filtros rápidos."
      navigation:
        - element: page_navigator
          action: PageNavigation
          target: "Portada, Tablero, Estadísticas"
          label: "Portada · Tablero · Estadísticas"
        - element: button
          action: ClearAllSlicers
          label: "Limpiar filtros"
      page_background: "#F4F6F3"
      layout_summary: "Cabecera verde (título, navegador, filtros); franja de KPIs compacta; tabla dominante a la izquierda; tres gráficos apilados a la derecha."
      layout_contract:
        canvas: { width: 1920, height: 1080, margin: 32, gutter: 24, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            bg_header:   [1, 1, 13, 2]
            header:      [1, 1, 6, 2]
            nav:         [6, 1, 8, 2]
            filters:     [8, 1, 13, 2]
            kpis:        [1, 2, 13, 3]
            table:       [1, 3, 9, 13]
            chart_month: [9, 3, 13, 6]
            chart_stage: [9, 6, 13, 9]
            chart_type:  [9, 9, 13, 13]
        placements:
          - id: header_band
            region: bg_header
            kind: shape
            purpose: "Franja verde de cabecera (estructura)"
          - id: page_title
            region: header
            kind: textbox
            text: "Líneas del PAA 2027 por necesidad"
            purpose: "Título de la página con escudo a la izquierda"
          - id: page_nav
            region: nav
            kind: pageNavigator
            purpose: "Navegar entre Portada, Tablero y Estadísticas"
          - id: slicer_solicitante
            region: filters
            kind: slicer
            field_bindings: "'Líneas PAA'[Solicitante]"
            slicer_type: dropdown
            slot: 1
            of: 4
          - id: slicer_tipo
            region: filters
            kind: slicer
            field_bindings: "'Líneas PAA'[Tipo de necesidad]"
            slicer_type: dropdown
            slot: 2
            of: 4
          - id: slicer_etapa
            region: filters
            kind: slicer
            field_bindings: "'Líneas PAA'[Etapa]"
            slicer_type: dropdown
            slot: 3
            of: 4
          - id: btn_limpiar
            region: filters
            kind: actionButton
            text: "Limpiar filtros"
            slot: 4
            of: 4
          - id: kpi_strip
            region: kpis
            kind: cardVisual
            purpose: "Resumen de la selección actual"
            field_bindings: ["'Líneas PAA'[Líneas PAA]", "'Líneas PAA'[Valor total PAA]", "'Líneas PAA'[Valor promedio por línea]", "'Líneas PAA'[Dependencias solicitantes]", "'Líneas PAA'[% líneas listas para comité]", "'Líneas PAA'[Líneas con ajuste solicitado]"]
            insight_basis: "Volumen, valor, dispersión y avance del flujo de la selección"
            color_strategy: measure_match
          - id: tabla_lineas
            region: table
            kind: tableEx
            purpose: "¿Qué líneas hay, de quién son, cuánto valen, cuándo inician y en qué etapa van?"
            field_bindings: ["'Líneas PAA'[Identificador]", "'Líneas PAA'[Tipo de necesidad]", "'Líneas PAA'[Descripción de la necesidad]", "'Líneas PAA'[Valor total PAA]", "'Líneas PAA'[Barra de valor SVG]", "'Líneas PAA'[Solicitante]", "'Líneas PAA'[Mes de inicio del proceso]", "'Líneas PAA'[Etapa SVG]"]
            sort_policy: value_desc
            color_strategy: measure_match
          - id: chart_valor_mes
            region: chart_month
            kind: columnChart
            purpose: "¿En qué mes inicia el proceso de las líneas y con cuánto valor?"
            field_bindings: { Category: "'Líneas PAA'[Mes de inicio del proceso]", Y: "'Líneas PAA'[Valor total PAA]" }
            sort_policy: natural_order
            color_strategy: measure_match
          - id: chart_etapa
            region: chart_stage
            kind: barChart
            purpose: "¿Cuántas líneas hay en cada etapa del flujo?"
            field_bindings: { Category: "'Líneas PAA'[Etapa]", Y: "'Líneas PAA'[Líneas PAA]" }
            sort_policy: natural_order
            color_strategy: semantic
          - id: chart_tipo
            region: chart_type
            kind: barChart
            purpose: "¿Qué tipo de necesidad concentra el valor?"
            field_bindings: { Category: "'Líneas PAA'[Tipo de necesidad]", Y: "'Líneas PAA'[Valor total PAA]" }
            sort_policy: value_desc
            color_strategy: measure_match
        space_audit:
          content_cell_count: 132
          placed_cell_count: 132
          empty_cell_pct: 0
          unplaced_regions: []
          largest_region: { name: table, pct_of_content: 61 }
          balance_rationale: "La tabla es el héroe por requisito explícito del usuario; la franja de KPIs se reduce a una fila para darle altura, y los tres gráficos de la derecha mantienen al menos 4×3 celdas."
    - name: "Estadísticas"
      role: detail
      archetype: Comparative
      layout_variant: A
      variant_rationale: "Seis distribuciones del mismo valor (tiempo, segmento, dependencia, fuente, duración) comparadas lado a lado."
      navigation:
        - element: page_navigator
          action: PageNavigation
          target: "Portada, Tablero, Estadísticas"
          label: "Portada · Tablero · Estadísticas"
      page_background: "#F4F6F3"
      layout_summary: "Cabecera verde; franja de 6 KPIs de contexto; dos gráficos anchos y tres gráficos en la fila inferior."
      layout_contract:
        canvas: { width: 1920, height: 1080, margin: 32, gutter: 24, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            bg_header: [1, 1, 13, 2]
            header:    [1, 1, 6, 2]
            nav:       [6, 1, 8, 2]
            filters:   [8, 1, 13, 2]
            kpis:      [1, 2, 13, 4]
            months:    [1, 4, 7, 8]
            segment:   [7, 4, 13, 8]
            top_deps:  [1, 8, 5, 13]
            source:    [5, 8, 9, 13]
            scatter:   [9, 8, 13, 13]
        placements:
          - id: header_band
            region: bg_header
            kind: shape
            purpose: "Franja verde de cabecera (estructura)"
          - id: page_title
            region: header
            kind: textbox
            text: "¿Dónde se concentra el valor del PAA 2027?"
          - id: page_nav
            region: nav
            kind: pageNavigator
          - id: slicer_solicitante
            region: filters
            kind: slicer
            field_bindings: "'Líneas PAA'[Solicitante]"
            slicer_type: dropdown
            slot: 1
            of: 4
          - id: slicer_tipo
            region: filters
            kind: slicer
            field_bindings: "'Líneas PAA'[Tipo de necesidad]"
            slicer_type: dropdown
            slot: 2
            of: 4
          - id: slicer_etapa
            region: filters
            kind: slicer
            field_bindings: "'Líneas PAA'[Etapa]"
            slicer_type: dropdown
            slot: 3
            of: 4
          - id: btn_limpiar
            region: filters
            kind: actionButton
            text: "Limpiar filtros"
            slot: 4
            of: 4
          - id: context_kpis
            region: kpis
            kind: cardVisual
            purpose: "Indicadores de concentración y calidad del dato"
            field_bindings: ["'Líneas PAA'[% valor contratación de personal]", "'Líneas PAA'[% valor primer trimestre]", "'Líneas PAA'[% valor top 5 dependencias]", "'Líneas PAA'[Duración promedio (meses)]", "'Líneas PAA'[Valor máximo de una línea]", "'Líneas PAA'[Líneas sin unidad de contratación]"]
            insight_basis: "Proporciones y umbrales que no aparecen en los gráficos absolutos de abajo"
            color_strategy: measure_match
          - id: chart_mes_combo
            region: months
            kind: lineClusteredColumnComboChart
            purpose: "¿Cómo se distribuyen el valor y el número de líneas por mes de inicio del proceso?"
            field_bindings: { Category: "'Líneas PAA'[Mes de inicio del proceso]", ColumnY: "'Líneas PAA'[Valor total PAA]", LineY: "'Líneas PAA'[Líneas PAA]" }
            sort_policy: natural_order
            color_strategy: measure_match
          - id: chart_segmento
            region: segment
            kind: barChart
            purpose: "¿Qué segmentos UNSPSC concentran el valor?"
            field_bindings: { Category: "'Líneas PAA'[Segmento UNSPSC]", Y: "'Líneas PAA'[Valor total PAA]" }
            sort_policy: value_desc
            color_strategy: measure_match
          - id: chart_dependencias
            region: top_deps
            kind: barChart
            purpose: "¿Cuáles son las 10 dependencias con más valor solicitado?"
            field_bindings: { Category: "'Líneas PAA'[Solicitante]", Y: "'Líneas PAA'[Valor total PAA]" }
            sort_policy: value_desc
            color_strategy: measure_match
          - id: chart_fuente
            region: source
            kind: donutChart
            purpose: "¿De qué fuentes de recursos sale el valor?"
            field_bindings: { Category: "'Líneas PAA'[Fuente de recursos]", Y: "'Líneas PAA'[Valor total PAA]" }
            color_strategy: unique
          - id: chart_dispersion
            region: scatter
            kind: scatterChart
            purpose: "¿Las líneas de mayor valor son también las de mayor duración?"
            field_bindings: { Details: "'Líneas PAA'[Identificador]", X: "'Líneas PAA'[Duración promedio (meses)]", Y: "'Líneas PAA'[Valor total PAA]", Legend: "'Líneas PAA'[Origen de la inversión]" }
            color_strategy: unique
        space_audit:
          content_cell_count: 132
          placed_cell_count: 132
          empty_cell_pct: 0
          unplaced_regions: []
          largest_region: { name: months, pct_of_content: 18 }
          balance_rationale: "Cinco gráficos de tamaño parejo y una franja de KPIs de dos filas; ninguna región domina porque la página compara distribuciones."
    - name: "Detalle de la necesidad"
      role: drillthrough
      archetype: Analytical
      layout_variant: A
      variant_rationale: "Una sola línea: datos clave a la izquierda y los textos largos (descripción y justificación) a la derecha."
      navigation:
        - element: button
          action: Back
          label: "Volver"
      page_background: "#F4F6F3"
      layout_summary: "Cabecera verde con botón Volver; tarjeta de datos clave; descripción; justificación completa."
      layout_contract:
        canvas: { width: 1920, height: 1080, margin: 32, gutter: 24, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            bg_header:     [1, 1, 13, 2]
            header:        [1, 1, 10, 2]
            nav:           [10, 1, 13, 2]
            facts:         [1, 2, 5, 13]
            description:   [5, 2, 13, 5]
            justification: [5, 5, 13, 13]
        placements:
          - id: header_band
            region: bg_header
            kind: shape
            purpose: "Franja verde de cabecera (estructura)"
          - id: page_title
            region: header
            kind: textbox
            text: "Detalle de la necesidad seleccionada"
          - id: btn_volver
            region: nav
            kind: actionButton
            text: "Volver"
          - id: ficha
            region: facts
            kind: cardVisual
            purpose: "Datos clave de la línea: identificador, valor, solicitante, fechas, duración, fuente, unidad, UNSPSC y etapa"
            field_bindings: ["'Líneas PAA'[Identificador]", "'Líneas PAA'[Valor total PAA]", "'Líneas PAA'[Solicitante]", "'Líneas PAA'[Tipo de necesidad]", "'Líneas PAA'[Mes de inicio del proceso]", "'Calendario'[Fecha]", "'Líneas PAA'[Duración]", "'Líneas PAA'[Unidad de duración]", "'Líneas PAA'[Fuente de recursos]", "'Líneas PAA'[Unidad de contratación]", "'Líneas PAA'[Código UNSPSC]", "'Líneas PAA'[Segmento UNSPSC]", "'Líneas PAA'[Etapa]", "'Líneas PAA'[Tarea actual]"]
            insight_basis: "Ficha completa de la línea filtrada por drillthrough"
            color_strategy: none
          - id: tabla_descripcion
            region: description
            kind: tableEx
            purpose: "¿Qué se va a contratar?"
            field_bindings: ["'Líneas PAA'[Descripción de la necesidad]"]
            sort_policy: none
          - id: tabla_justificacion
            region: justification
            kind: tableEx
            purpose: "¿Por qué se necesita?"
            field_bindings: ["'Líneas PAA'[Justificación]"]
            sort_policy: none
        space_audit:
          content_cell_count: 132
          placed_cell_count: 132
          empty_cell_pct: 0
          unplaced_regions: []
          largest_region: { name: justification, pct_of_content: 48 }
          balance_rationale: "La justificación llega a 3.000 caracteres y necesita la región más alta; la ficha conserva una columna completa."
    - name: "Vista rápida de la línea"
      role: tooltip
      archetype: Analytical
      layout_variant: A
      variant_rationale: "Tooltip compacto para la fila de la tabla."
      navigation: []
      page_background: "#FFFFFF"
      layout_summary: "Título, tres datos clave y la descripción."
      layout_contract:
        canvas: { width: 480, height: 320, margin: 12, gutter: 8, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            header:      [1, 1, 13, 3]
            facts:       [1, 3, 13, 6]
            description: [1, 6, 13, 13]
        placements:
          - id: page_title
            region: header
            kind: textbox
            text: "Vista rápida de la línea"
          - id: tooltip_ficha
            region: facts
            kind: cardVisual
            purpose: "Valor, solicitante y etapa de la fila"
            field_bindings: ["'Líneas PAA'[Valor total PAA]", "'Líneas PAA'[Solicitante]", "'Líneas PAA'[Etapa]"]
            color_strategy: none
          - id: tooltip_descripcion
            region: description
            kind: tableEx
            purpose: "Descripción de la necesidad"
            field_bindings: ["'Líneas PAA'[Descripción de la necesidad]"]
            sort_policy: none
        space_audit:
          content_cell_count: 120
          placed_cell_count: 120
          empty_cell_pct: 0
          unplaced_regions: []
          largest_region: { name: description, pct_of_content: 70 }
          balance_rationale: "En un tooltip la descripción es lo que el usuario quiere leer."
  interaction_pattern:
    drill_targets: ["Detalle de la necesidad (por 'Líneas PAA'[Identificador])"]
    cross_filter_rules: "Gráficos del Tablero → tabla: Filter. KPIs: None (solo reciben filtros). Estadísticas: Highlight entre gráficos."
  accessibility:
    alt_text_strategy: "pregunta del gráfico + qué muestra (p. ej., 'Valor por mes de inicio del proceso; febrero concentra la mayor parte')"
    contrast_notes: "Amarillo #FBE122 solo como relleno con texto #1F2A24 o como acento sobre verde; blanco sobre #00482B; rojo de etapa oscurecido a #B3121A para cumplir AA con texto blanco."
  theme:
    base: "references/design/assets/base.json adaptado a la paleta UCundinamarca"
    user_overrides: "Usar solo los logos oficiales de la carpeta NUEVA IMAGEN UCUNDINAMARCA 2026, sin deformarlos ni recolorearlos."
```

## Implementation notes

- Model changes:
  - Crear el modelo con el Modeling MCP (base de datos offline, nivel de compatibilidad 1702 o superior, cultura es-CO).
  - Exportar a TMDL en `Lineas PAA 2027.SemanticModel/definition`.
  - Abrir en Desktop, actualizar los datos y validar las medidas con DAX.
- PBIR/report authoring: andamiaje PBIP; páginas y visuales en PBIR con las referencias del modo `authoring`; tema personalizado; logos y SVG como recursos registrados.
- Validation: `powerbi-report-author validate` después de cada lote.
- Desktop screenshot verification: `powerbi-report-author preview --host desktop --status`, luego `--reload` y `--screenshot --all-pages`. Las animaciones no se ven en una captura estática: se revisan en Desktop.
- Publishing boundary: nada sale del equipo; publicar requiere `/pbi-nube`.
- Risks:
  - Las animaciones SVG dependen del motor de imágenes de Power BI. Si una animación no se reproduce, la imagen se ve estática, sin errores.
  - La ruta del CSV queda en el parámetro `Carpeta de datos` y se cambia allí si el proyecto se mueve de carpeta.
