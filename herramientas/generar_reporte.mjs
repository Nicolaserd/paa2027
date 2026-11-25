// Genera el informe PBIR "Lineas PAA 2027" a partir del spec aprobado (_brief/report-spec.md).
//
// Uso (desde la raíz del proyecto):   node herramientas/generar_reporte.mjs
//
// ATENCIÓN: reescribe por completo las páginas, el tema y los recursos del informe
// (Lineas PAA 2027.Report/definition/pages y StaticResources/RegisteredResources).
// Los cambios hechos a mano en Power BI Desktop sobre esas páginas se pierden.
// Los identificadores de páginas y visuales son deterministas (hash del nombre),
// así que volver a ejecutarlo produce diffs pequeños en git.

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, readdirSync, copyFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), "..");
const REPORT = join(RAIZ, "Lineas PAA 2027.Report");
const DEF = join(REPORT, "definition");
const RR = join(REPORT, "StaticResources", "RegisteredResources");
const MARCA = join(RAIZ, "NUEVA IMAGEN UCUNDINAMARCA 2026", "PNG");

const T = "Líneas PAA";          // tabla de hechos
const CAL = "Calendario";
const SCHEMA_VISUAL = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.9.0/schema.json";
const SCHEMA_PAGE = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json";
const SCHEMA_PAGES = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json";

// Paleta UCundinamarca sobria (muestreada de los logos oficiales): verde institucional,
// oliva del listón del escudo, gris y salvia. Sin amarillo ni dorado por decisión del usuario.
const C = {
  verde: "#00482B", verdeOscuro: "#00321E", verdeClaro: "#DCE9E2", salvia: "#D7E6DD", salviaMedia: "#A9C4B6",
 gris: "#4D4D4D", rojo: "#B3121A", azul: "#2C7DA0", oliva: "#8B7D36",
  texto: "#1F2A24", textoSuave: "#5B6B62", fondo: "#F4F6F3", blanco: "#FFFFFF", linea: "#DDE5E0",
};

// ---------- utilidades ----------
const h = (s, n = 20) => createHash("sha1").update(s).digest("hex").slice(0, n);
const lit = (v) => ({ expr: { Literal: { Value: v } } });
const str = (s) => lit(`'${String(s).replace(/'/g, "''")}'`);
const num = (n) => lit(`${n}D`);
const int = (n) => lit(`${n}L`);
const bool = (b) => lit(b ? "true" : "false");
const col = (hex) => ({ solid: { color: str(hex) } });
const colExpr = (field) => ({ solid: { color: { expr: field } } });
const props = (p, selector) => (selector ? { properties: p, selector } : { properties: p });
const id = (s) => ({ id: s });

const fCol = (table, p) => ({ Column: { Expression: { SourceRef: { Entity: table } }, Property: p } });
const fMea = (table, p) => ({ Measure: { Expression: { SourceRef: { Entity: table } }, Property: p } });
const pr = (field, displayName) => {
  const k = field.Column || field.Measure;
  const o = { field, queryRef: `${k.Expression.SourceRef.Entity}.${k.Property}`, nativeQueryRef: k.Property };
  if (displayName) o.displayName = displayName;
  return o;
};
const qref = (table, p) => `${table}.${p}`;

const writeJson = (path, obj) => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(obj, null, 2) + "\n", "utf8");
};

// VCO comunes
const vcoNone = () => ({
  background: [props({ show: bool(false) })],
  border: [props({ show: bool(false) })],
  padding: [props({ top: num(0), bottom: num(0), left: num(0), right: num(0) })],
});
const vcoPanel = (titulo, alt, subtitulo) => {
  const v = {
    title: [props({ show: bool(true), text: str(titulo), fontColor: col(C.texto), fontSize: num(13), bold: bool(true), fontFamily: str("Segoe UI Semibold") })],
    background: [props({ show: bool(true), color: col(C.blanco), transparency: num(0) })],
    border: [props({ show: bool(true), color: col(C.linea), radius: num(10) })],
    padding: [props({ top: num(10), bottom: num(10), left: num(14), right: num(14) })],
    general: [props({ altText: str(alt) })],
  };
  if (subtitulo) v.subTitle = [props({ show: bool(true), text: str(subtitulo), fontColor: col(C.textoSuave), fontSize: num(10) })];
  return v;
};

// ---------- definición de páginas ----------
// Portada + una sola página de tablero (tabla, KPIs, gráficas, estadísticas y filtros).
// El tablero mide 1920 x ALTO_TABLERO y se muestra "Ajustar al ancho" con desplazamiento vertical.
const ALTO_TABLERO = 1968;
const PAGINAS = {
  portada: { id: h("pagina-portada"), nombre: "Portada" },
  tablero: { id: h("pagina-tablero"), nombre: "Tablero PAA 2027" },
};

const visuales = {}; // pageKey -> [visual.json]
let zCounter = {};
function visual(pageKey, key, type, pos, visualBody, extra = {}) {
  zCounter[pageKey] = (zCounter[pageKey] || 0) + 1000;
  const z = pos.z ?? zCounter[pageKey];
  const v = {
    $schema: SCHEMA_VISUAL,
    name: h(`${pageKey}/${key}`),
    position: { x: pos.x, y: pos.y, z, height: pos.h, width: pos.w, tabOrder: pos.tab ?? z },
    visual: { visualType: type, ...visualBody },
    ...extra,
  };
  (visuals[pageKey] ||= []).push(v);
  return v;
}
const visuals = visuales;

// ---------- recursos (logos y SVG animados) ----------
const RECURSOS = {
  logoAlta: "logo-alta-calidad-blanco20261125.png",
  logoBlanco: "logo-horizontal-blanco20261125.png",
  fondo: "portada-fondo20261125.svg",
  emblema: "portada-emblema20261125.svg",
};

function svgFondo() {
  const anillos = Array.from({ length: 11 }, (_, i) => 380 + i * 70)
    .map((r, i) => `<circle cx="1530" cy="540" r="${r}" fill="none" stroke="#FFFFFF" stroke-opacity="${(0.07 - i * 0.004).toFixed(3)}" stroke-width="1.2" stroke-dasharray="${i % 2 ? "2 10" : "14 8"}" class="${i % 2 ? "g1" : "g2"}"/>`)
    .join("");
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#005433"/><stop offset=".55" stop-color="#00482B"/><stop offset="1" stop-color="#00321E"/></linearGradient>
<radialGradient id="luz" cx="1530" cy="540" r="620" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#1E7A52" stop-opacity=".55"/><stop offset="1" stop-color="#00482B" stop-opacity="0"/></radialGradient>
<linearGradient id="cinta" x1="0" x2="1"><stop offset="0" stop-color="#1E6B48"/><stop offset=".5" stop-color="#A9C4B6"/><stop offset="1" stop-color="#1E6B48"/></linearGradient>
</defs>
<style>
.g1{transform-origin:1530px 540px;animation:giro 140s linear infinite}
.g2{transform-origin:1530px 540px;animation:giro 200s linear infinite reverse}
.luz{animation:respira 7s ease-in-out infinite}
.diag{animation:desliza 9s ease-in-out infinite alternate}
@keyframes giro{to{transform:rotate(360deg)}}
@keyframes respira{0%,100%{opacity:.75}50%{opacity:1}}
@keyframes desliza{from{transform:translateX(0)}to{transform:translateX(26px)}}
</style>
<rect width="1920" height="1080" fill="url(#bg)"/>
<rect class="luz" width="1920" height="1080" fill="url(#luz)"/>
<g>${anillos}</g>
<g class="diag" stroke="#FFFFFF" stroke-opacity=".06" stroke-width="2">
<line x1="-40" y1="1080" x2="320" y2="720"/><line x1="20" y1="1080" x2="380" y2="720"/><line x1="80" y1="1080" x2="440" y2="720"/>
</g>
<rect y="1068" width="1920" height="12" fill="url(#cinta)"/>
</svg>`;
}

function svgEmblema(escudoB64) {
  const cx = 350, cy = 420;
  const puntos = [];
  for (let i = 0; i < 32; i++) {
    const r = i % 2 ? 292 : 318;
    const a = (Math.PI * 2 * i) / 32 - Math.PI / 2;
    puntos.push(`${(cx + r * Math.cos(a)).toFixed(1)},${(cy + r * Math.sin(a)).toFixed(1)}`);
  }
  const circ = (2 * Math.PI * 262).toFixed(1);
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="700" height="840" viewBox="0 0 700 840">
<defs><path id="arco" d="M ${cx} ${cy} m -338 0 a 338 338 0 1 1 676 0 a 338 338 0 1 1 -676 0"/></defs>
<style>
.estrella{transform-origin:${cx}px ${cy}px;animation:giro 90s linear infinite}
.texto{transform-origin:${cx}px ${cy}px;animation:giro 120s linear infinite reverse}
.trazo{stroke-dasharray:${circ};stroke-dashoffset:${circ};animation:dibuja 2.8s cubic-bezier(.4,0,.2,1) .3s forwards}
.halo{transform-origin:${cx}px ${cy}px;animation:pulso 4.5s ease-in-out infinite}
.orbita1{transform-origin:${cx}px ${cy}px;animation:giro 14s linear infinite}
.orbita2{transform-origin:${cx}px ${cy}px;animation:giro 21s linear infinite reverse}
.orbita3{transform-origin:${cx}px ${cy}px;animation:giro 28s linear infinite}
.escudo{animation:entra 1.6s cubic-bezier(.2,.8,.2,1) both,flota 7s ease-in-out 1.6s infinite}
@keyframes giro{to{transform:rotate(360deg)}}
@keyframes dibuja{to{stroke-dashoffset:0}}
@keyframes pulso{0%,100%{transform:scale(.96);opacity:.10}50%{transform:scale(1.04);opacity:.20}}
@keyframes entra{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:translateY(0)}}
@keyframes flota{0%,100%{transform:translateY(0)}50%{transform:translateY(-8px)}}
</style>
<circle class="halo" cx="${cx}" cy="${cy}" r="250" fill="#FFFFFF"/>
<polygon class="estrella" points="${puntos.join(" ")}" fill="none" stroke="#D7E6DD" stroke-opacity=".40" stroke-width="2" stroke-linejoin="round"/>
<circle cx="${cx}" cy="${cy}" r="262" fill="none" stroke="#FFFFFF" stroke-opacity=".12" stroke-width="10"/>
<circle class="trazo" cx="${cx}" cy="${cy}" r="262" fill="none" stroke="#A9C4B6" stroke-width="4" stroke-linecap="round" transform="rotate(-90 ${cx} ${cy})"/>
<g class="texto"><text font-family="Segoe UI, Arial, sans-serif" font-size="17" font-weight="600" letter-spacing="5" fill="#D7E6DD" fill-opacity=".80"><textPath xlink:href="#arco" href="#arco">PLAN ANUAL DE ADQUISICIONES · VIGENCIA 2027 · UNIVERSIDAD DE CUNDINAMARCA ·</textPath></text></g>
<g class="orbita1"><circle cx="${cx}" cy="${cy - 262}" r="9" fill="#FFFFFF"/></g>
<g class="orbita2"><circle cx="${cx}" cy="${cy + 262}" r="8" fill="#A9C4B6"/></g>
<g class="orbita3"><circle cx="${cx + 262}" cy="${cy}" r="7" fill="#D7E6DD"/></g>
<image class="escudo" x="${cx - 150}" y="${cy - 224}" width="300" height="449" href="data:image/png;base64,${escudoB64}" xlink:href="data:image/png;base64,${escudoB64}"/>
</svg>`;
}

// ---------- tema ----------
function tema() {
  const ejes = { gridlineStyle: "dotted", gridlineColor: { solid: { color: "#E6ECE8" } } };
  const barras = (legend) => ({
    "*": {
      labels: [{ show: true, fontSize: 10, color: { solid: { color: C.texto } } }],
      valueAxis: [{ show: false, gridlineShow: false, showAxisTitle: false }],
      categoryAxis: [{ show: true, fontSize: 10, labelColor: { solid: { color: C.textoSuave } }, showAxisTitle: false, gridlineShow: false }],
      dataPoint: [{ borderShow: false }],
      legend: [{ show: legend, fontSize: 10, labelColor: { solid: { color: C.textoSuave } } }],
    },
  });
  return {
    $schema: "https://raw.githubusercontent.com/microsoft/powerbi-desktop-samples/main/Report%20Theme%20JSON%20Schema/reportThemeSchema-2.153.json",
    name: "",
    dataColors: [C.verde, C.oliva, C.azul, "#5E8C74", "#7FA393", C.rojo, C.gris, "#A3B8AD", "#B0A577", "#3E6B55", "#C9D6CE", "#6E6E6E"],
    good: "#1E7A52", neutral: C.oliva, bad: C.rojo,
    maximum: C.verde, center: C.oliva, minimum: C.verdeClaro, null: "#C9C9C9",
    foreground: C.texto, background: C.blanco, tableAccent: C.verde,
    textClasses: {
      callout: { fontSize: 26, fontFace: "Segoe UI Semibold", color: C.verde },
      title: { fontSize: 13, fontFace: "Segoe UI Semibold", color: C.texto },
      header: { fontSize: 12, fontFace: "Segoe UI Semibold", color: C.texto },
      label: { fontSize: 10, fontFace: "Segoe UI", color: C.texto },
    },
    visualStyles: {
      "*": { "*": {
        border: [{ show: true, color: { solid: { color: C.linea } }, radius: 10 }],
        dropShadow: [{ show: false }],
        padding: [{ top: 8, bottom: 8, left: 8, right: 8 }],
        categoryAxis: [ejes], valueAxis: [ejes],
      } },
      page: { "*": { background: [{ color: { solid: { color: C.fondo } }, transparency: 0 }], outspace: [{ color: { solid: { color: "#E4EAE6" } } }] } },
      tableEx: { "*": {
        columnHeaders: [{ autoSizeColumnWidth: true, columnAdjustment: "growToFit", backColor: { solid: { color: C.verde } }, fontColor: { solid: { color: C.blanco } }, bold: true }],
        values: [{ backColorPrimary: { solid: { color: C.blanco } }, backColorSecondary: { solid: { color: "#F3F7F4" } }, fontColorPrimary: { solid: { color: C.texto } }, fontColorSecondary: { solid: { color: C.texto } } }],
      } },
      cardVisual: { "*": {
        value: [{ bold: true, $id: "default" }],
        label: [{ show: true, $id: "default" }],
        title: [{ show: false }],
      } },
      textbox: { "*": { padding: [{ top: 0, bottom: 0, left: 0, right: 0 }], background: [{ show: false }], border: [{ show: false }] } },
      barChart: barras(false), columnChart: barras(false), clusteredBarChart: barras(true), clusteredColumnChart: barras(true),
      lineClusteredColumnComboChart: { "*": { legend: [{ show: true, position: "Top", fontSize: 10 }], categoryAxis: [{ showAxisTitle: false, fontSize: 10 }], valueAxis: [{ showAxisTitle: false, gridlineShow: true }] } },
    },
  };
}

// ---------- bloques reutilizables ----------
function cabecera(pageKey, titulo) {
  visual(pageKey, "franja", "shape", { x: 0, y: 0, w: 1920, h: 88, z: 0, tab: 0 }, {
    objects: {
      shape: [props({ tileShape: str("rectangle") })],
      fill: [props({ fillColor: col(C.verde), transparency: num(0) }, id("default"))],
      outline: [props({ show: bool(false) }, id("default"))],
    },
    visualContainerObjects: vcoNone(),
  });
  visual(pageKey, "franja-dorada", "shape", { x: 0, y: 88, w: 1920, h: 4, z: 1, tab: 1 }, {
    objects: {
      shape: [props({ tileShape: str("rectangle") })],
      fill: [props({ fillColor: col(C.oliva), transparency: num(0) }, id("default"))],
      outline: [props({ show: bool(false) }, id("default"))],
    },
    visualContainerObjects: vcoNone(),
  });
  visual(pageKey, "logo", "image", { x: 32, y: 16, w: 192, h: 56 }, {
    objects: {
      general: [props({ imageUrl: { expr: { ResourcePackageItem: { PackageName: "RegisteredResources", PackageType: 1, ItemName: RECURSOS.logoBlanco } } } })],
      imageScaling: [props({ imageScalingType: str("Fit") })],
    },
    visualContainerObjects: { ...vcoNone(), general: [props({ altText: str("Logo Universidad de Cundinamarca") })] },
    drillFilterOtherVisuals: true,
  });
  visual(pageKey, "separador", "shape", { x: 240, y: 24, w: 2, h: 40 }, {
    objects: {
      shape: [props({ tileShape: str("rectangle") })],
      fill: [props({ fillColor: col(C.blanco), transparency: num(65) }, id("default"))],
      outline: [props({ show: bool(false) }, id("default"))],
    },
    visualContainerObjects: vcoNone(),
  });
  visual(pageKey, "page_title", "textbox", { x: 256, y: 20, w: 360, h: 48 }, {
    objects: { general: [props({ paragraphs: [{ textRuns: [{ value: titulo, textStyle: { fontFamily: "Segoe UI Semibold", fontSize: "22px", color: C.blanco } }], horizontalTextAlignment: "left" }] })] },
    visualContainerObjects: vcoNone(),
  });
}

function buscador(pageKey, key, campo, marcador, pos) {
  visual(pageKey, key, "textSlicer", pos, {
    query: { queryState: { Values: { projections: [pr(fCol(T, campo))] } } },
    objects: {
      inputTextBox: [props({
        backShow: bool(true), backColor: col(C.blanco), backTransparency: num(0),
        borderShow: bool(false), containerCornerRadius: int(10),
        accentBarShow: bool(true), accentBarPosition: str("--accent-bar-left"), accentBarColor: col(C.oliva), accentBarWidth: num(4),
        placeholder: str(marcador), placeholderFontColor: col(C.textoSuave), placeholderFontSize: num(11),
      })],
      inputText: [props({ fontColor: col(C.texto), fontSize: num(11), backShow: bool(true), backColor: col(C.verdeClaro), pillCornerRadius: int(10) })],
    },
    visualContainerObjects: {
      background: [props({ show: bool(false) })],
      border: [props({ show: bool(false) })],
      padding: [props({ top: num(0), bottom: num(0), left: num(0), right: num(0) })],
      title: [props({ show: bool(false) })],
      general: [props({ altText: str("Búsqueda de texto en la descripción de la necesidad") })],
    },
  });
}

function slicer(pageKey, key, campo, titulo, x, w) {
  visual(pageKey, key, "slicer", { x, y: 6, w, h: 76 }, {
    query: { queryState: { Values: { projections: [pr(fCol(T, campo))] } } },
    objects: {
      data: [props({ mode: str("Dropdown") })],
      general: [props({ selfFilterEnabled: bool(true) })],
      header: [props({ show: bool(true), text: str(titulo), fontColor: col(C.blanco) })],
      items: [props({ fontColor: col(C.texto), background: col(C.blanco), textSize: num(10) })],
    },
    visualContainerObjects: {
      background: [props({ show: bool(false) })],
      border: [props({ show: bool(false) })],
      padding: [props({ top: num(4), bottom: num(4), left: num(4), right: num(4) })],
      general: [props({ altText: str(`Filtro por ${titulo.toLowerCase()}`) })],
    },
  });
}

function boton(pageKey, key, pos, texto, accion, estilo, extraLink = {}, icono = null) {
  const relleno = estilo === "primario" ? C.blanco : estilo === "claro" ? C.blanco : C.verde;
  const tinta = estilo === "primario" ? C.verde : estilo === "claro" ? C.verde : C.blanco;
  const hover = estilo === "primario" ? C.salvia : estilo === "claro" ? C.salvia : "#0B5E3A";
  const transp = estilo === "fantasma" ? 100 : 0;
  visual(pageKey, key, "actionButton", pos, {
    objects: {
      text: [
        props({ show: bool(true) }),
        props({ text: str(texto), fontSize: num(pos.h >= 52 ? 14 : 11), bold: bool(true), fontColor: col(tinta), horizontalAlignment: str("center"), fontFamily: str("Segoe UI Semibold") }, id("default")),
        props({ fontColor: col(estilo === "fantasma" ? C.verde : tinta) }, id("hover")),
      ],
      icon: [
        props({ show: bool(!!icono) }),
        props({ shapeType: str(icono || "rightArrow"), placement: str(icono === "leftArrow" ? "left" : "right"), lineColor: col(tinta) }, id("default")),
        props({ lineColor: col(estilo === "fantasma" ? C.verde : tinta) }, id("hover")),
      ],
      fill: [
        props({ show: bool(true) }),
        props({ fillColor: col(relleno), transparency: num(transp) }, id("default")),
        props({ fillColor: col(hover), transparency: num(0) }, id("hover")),
      ],
      outline: [
        props({ show: bool(estilo === "fantasma") }),
        props({ lineColor: col(C.blanco), weight: num(2) }, id("default")),
      ],
      shape: [props({ tileShape: str("rectangleRounded"), roundEdge: int(10) }), props({ tileShape: str("rectangleRounded") }, id("default"))],
    },
    visualContainerObjects: {
      background: [props({ show: bool(false) })],
      border: [props({ show: bool(false) })],
      visualLink: [props({ show: bool(true), type: str(accion), ...extraLink })],
    },
    drillFilterOtherVisuals: true,
  }, { howCreated: "InsertVisualButton" });
}

function texto(pageKey, key, pos, valor, estilo, alineacion = "left") {
  return visual(pageKey, key, "textbox", pos, {
    objects: { general: [props({ paragraphs: [{ textRuns: [{ value: valor, textStyle: estilo }], horizontalTextAlignment: alineacion }] })] },
    visualContainerObjects: vcoNone(),
  });
}

// Conteos de líneas por "Tipo de Necesidad" (columna C del Excel) con estilo editorial:
// nombre del tipo en un cuadro de texto (ajusta en dos líneas), número grande debajo y "líneas"
// como etiqueta, separados por líneas verticales finas. Un item sin "tipo" muestra el total.
const TIPOS_NECESIDAD = [
  "Contratación de personal - Proyectos de inversión",
  "Proyecto de Inversión",
  "Fondos Inversión",
  "Fondos de Inversión-Contratación de Personal",
];
function conteos(pageKey, key, area, items, oscuro = false) {
  const gap = area.gap ?? 32;
  const n = items.length;
  const cw = Math.floor((area.w - gap * (n - 1)) / n);
  const hNombre = area.hNombre ?? 40;
  const hNum = oscuro ? 84 : 72;
  const tinta = oscuro ? C.blanco : C.verde;
  const etiqueta = oscuro ? C.salvia : C.textoSuave;
  items.forEach((it, i) => {
    const x = area.x + i * (cw + gap);
    texto(pageKey, `${key}_nombre_${i}`, { x: x + 16, y: area.y, w: cw - 16, h: hNombre }, it.nombre,
      { fontFamily: "Segoe UI Semibold", fontSize: oscuro ? "15px" : "14px", color: etiqueta });
    const filtro = it.tipo ? { filterConfig: { filters: [{
      name: "Filter" + h(`${pageKey}/${key}/${i}`, 24),
      field: fCol(T, "Tipo de necesidad"),
      type: "Categorical",
      filter: {
        Version: 2,
        From: [{ Name: "l", Entity: T, Type: 0 }],
        Where: [{ Condition: { In: {
          Expressions: [{ Column: { Expression: { SourceRef: { Source: "l" } }, Property: "Tipo de necesidad" } }],
          Values: [[{ Literal: { Value: `'${it.tipo.replace(/'/g, "''")}'` } }]],
        } } }],
      },
      howCreated: "User",
    }] } } : {};
    visual(pageKey, `${key}_numero_${i}`, "cardVisual", { x, y: area.y + hNombre, w: cw, h: hNum }, {
      query: { queryState: { Data: { projections: [pr(fMea(T, "Líneas PAA"), "líneas")] } } },
      objects: {
        value: [props({ fontSize: num(oscuro ? 34 : 28), fontColor: col(tinta), bold: bool(true), fontFamily: str("Segoe UI Semibold"), horizontalAlignment: str("left") }, id("default"))],
        label: [props({ show: bool(true), position: str("belowValue"), fontSize: num(11), fontColor: col(etiqueta), horizontalAlignment: str("left") }, id("default"))],
        outline: [props({ show: bool(false) }, id("default"))],
        accentBar: [props({ show: bool(false) }, id("default"))],
        fillCustom: [props({ transparency: num(100) }, id("default"))],
        padding: [props({ paddingUniform: num(0) }, id("default"))],
        layout: [props({ paddingUniform: num(0) }, id("default"))],
        cardCalloutArea: [props({ show: bool(false), paddingUniform: int(0) })],
      },
      visualContainerObjects: {
        background: [props({ show: bool(false) })],
        border: [props({ show: bool(false) })],
        padding: [props({ top: num(0), bottom: num(0), left: num(0), right: num(0) })],
        title: [props({ show: bool(false) })],
        general: [props({ altText: str(`Número de líneas: ${it.nombre}`) })],
      },
    }, filtro);
    if (i > 0) {
      visual(pageKey, `${key}_division_${i}`, "shape", { x: x - gap / 2, y: area.y + 4, w: 1, h: hNombre + hNum - 8 }, {
        objects: {
          shape: [props({ tileShape: str("rectangle") })],
          fill: [props({ fillColor: col(oscuro ? C.blanco : "#C3CEC8"), transparency: num(oscuro ? 70 : 0) }, id("default"))],
          outline: [props({ show: bool(false) }, id("default"))],
        },
        visualContainerObjects: vcoNone(),
      });
    }
  });
}

const etiquetasMillones = () => [props({ show: bool(true), labelPosition: str("OutsideEnd"), labelDisplayUnits: lit("1000000D"), labelPrecision: int(0), fontSize: num(10), color: col(C.texto) })];


// ---------- PORTADA ----------
const P = PAGINAS;
const img = (item) => ({ expr: { ResourcePackageItem: { PackageName: "RegisteredResources", PackageType: 1, ItemName: item } } });
visual("portada", "bg_texture", "image", { x: 0, y: 0, w: 1920, h: 1080, z: 0, tab: 0 }, {
  objects: { general: [props({ imageUrl: img(RECURSOS.fondo) })], imageScaling: [props({ imageScalingType: str("Fill") })] },
  visualContainerObjects: { ...vcoNone(), general: [props({ altText: str("Fondo institucional verde con anillos animados") })] },
});
visual("portada", "logo_horizontal", "image", { x: 64, y: 48, w: 352, h: 72 }, {
  objects: { general: [props({ imageUrl: img(RECURSOS.logoAlta) })], imageScaling: [props({ imageScalingType: str("Fit") })] },
  visualContainerObjects: { ...vcoNone(), general: [props({ altText: str("Logo Universidad de Cundinamarca con sello de Acreditación Institucional de Alta Calidad") })] },
});
visual("portada", "emblem_animado", "image", { x: 1176, y: 112, w: 700, h: 840 }, {
  objects: { general: [props({ imageUrl: img(RECURSOS.emblema) })], imageScaling: [props({ imageScalingType: str("Fit") })] },
  visualContainerObjects: { ...vcoNone(), general: [props({ altText: str("Escudo de la Universidad de Cundinamarca rodeado por anillos y una estrella animados") })] },
});
const barraAcento = (pageKey, key, pos, color) => visual(pageKey, key, "shape", pos, {
  objects: {
    shape: [props({ tileShape: str("rectangle") })],
    fill: [props({ fillColor: col(color), transparency: num(0) }, id("default"))],
    outline: [props({ show: bool(false) }, id("default"))],
  },
  visualContainerObjects: vcoNone(),
});
texto("portada", "overline", { x: 64, y: 248, w: 1040, h: 40 }, "PLAN ANUAL DE ADQUISICIONES  ·  VIGENCIA 2027", { fontFamily: "Segoe UI Semibold", fontSize: "20px", color: C.salvia });
texto("portada", "page_title", { x: 64, y: 280, w: 1080, h: 144 }, "Líneas del PAA 2027", { fontFamily: "Segoe UI Black", fontSize: "88px", color: C.blanco });
barraAcento("portada", "acento", { x: 64, y: 432, w: 136, h: 8 }, C.oliva);
texto("portada", "subtitle", { x: 64, y: 456, w: 1060, h: 72 }, "Necesidades nuevas registradas por las dependencias de la Universidad de Cundinamarca: qué se pide, quién lo pide, cuánto vale y en qué etapa va.", { fontFamily: "Segoe UI", fontSize: "20px", color: "#D7E6DD" });
// Portada: solo el conteo de líneas por "Tipo de Necesidad" (columna C del Excel), una celda por tipo.
texto("portada", "titulo_conteo", { x: 64, y: 536, w: 1080, h: 32 }, "Líneas por tipo de necesidad",
  { fontFamily: "Segoe UI Semibold", fontSize: "16px", color: C.salvia });
conteos("portada", "conteo", { x: 64, y: 568, w: 1080, gap: 24, hNombre: 56 }, [
  { nombre: "Total de líneas" },
  ...TIPOS_NECESIDAD.map((t) => ({ nombre: t, tipo: t })),
], true);
boton("portada", "btn_explorar", { x: 64, y: 736, w: 260, h: 56 }, "Explorar el tablero", "PageNavigation", "primario", { navigationSection: str(P.tablero.id), tooltip: str("Ir al tablero de líneas del PAA") }, "rightArrow");
texto("portada", "source_note", { x: 64, y: 1000, w: 1080, h: 40 }, "Fuente: LINEAS NUEVAS PAA 2027 (exportación del sistema PAA, corte 25/11/2026). Valores en pesos colombianos.", { fontFamily: "Segoe UI", fontSize: "13px", color: "#A9C4B6" });

// ---------- TABLERO (una sola página) ----------
// Bloque 1 (primera pantalla): cabecera con filtros, KPIs, tabla dominante y 3 gráficas.
cabecera("tablero", "Líneas del PAA 2027");
boton("tablero", "btn_portada", { x: 616, y: 20, w: 136, h: 48 }, "Portada", "PageNavigation", "fantasma", { navigationSection: str(P.portada.id), tooltip: str("Volver a la portada") }, "leftArrow");
buscador("tablero", "buscar_descripcion", "Descripción de la necesidad", "Buscar en la descripción…", { x: 768, y: 20, w: 392, h: 48 });
slicer("tablero", "slicer_solicitante", "Solicitante", "Solicitante", 1176, 184);
slicer("tablero", "slicer_tipo", "Tipo de necesidad", "Tipo de necesidad", 1376, 176);
slicer("tablero", "slicer_etapa", "Etapa", "Etapa", 1568, 128);
boton("tablero", "btn_limpiar", { x: 1712, y: 20, w: 176, h: 48 }, "Limpiar filtros", "ClearAllSlicers", "claro", { tooltip: str("Quitar todos los filtros de la página") }, "clearAllSlicers");

conteos("tablero", "conteo", { x: 32, y: 108, w: 1856 }, [
  { nombre: "Total de líneas" },
  ...TIPOS_NECESIDAD.map((t) => ({ nombre: t, tipo: t })),
]);

// Las 6 columnas con encabezado coloreado en el Excel, en su orden original (A, C, E, J, K, L).
const COLS_TABLA = [
  [fCol(T, "Identificador"), "Identificador", 100],
  [fCol(T, "Tipo de necesidad"), "Tipo de necesidad", 180],
  [fCol(T, "Descripción de la necesidad"), "Descripción de la necesidad", 414],
  [fMea(T, "Valor total PAA"), "Valor total de la necesidad", 180],
  [fCol(T, "Solicitante"), "Nombre del solicitante", 194],
  [fCol(T, "Mes de inicio del proceso"), "Fecha estimada de inicio del proceso", 128],
];
visual("tablero", "tabla_lineas", "tableEx", { x: 32, y: 248, w: 1240, h: 800 }, {
  query: {
    queryState: { Values: { projections: COLS_TABLA.map(([f, n]) => pr(f, n)) } },
    sortDefinition: { sort: [{ field: fMea(T, "Valor total PAA"), direction: "Descending" }], isDefaultSort: false },
  },
  objects: {
    columnHeaders: [props({ backColor: col(C.verde), fontColor: col(C.blanco), bold: bool(true), fontSize: num(10), wordWrap: bool(true), autoSizeColumnWidth: bool(false), columnAdjustment: str("fixedWidth") })],
    columnWidth: COLS_TABLA.map(([f, , w]) => props({ value: num(w) }, { metadata: qref(T, (f.Column || f.Measure).Property) })),
    columnFormatting: [props({
      dataBars: {
        positiveColor: col("#BFDCCB"), negativeColor: col(C.rojo), axisColor: col("#9DB8A9"),
        reverseDirection: bool(false), hideText: bool(false),
      },
    }, { metadata: qref(T, "Valor total PAA") })],
    values: [props({ fontSize: num(10), wordWrap: bool(true), backColorPrimary: col(C.blanco), backColorSecondary: col("#F3F7F4"), fontColorPrimary: col(C.texto), fontColorSecondary: col(C.texto) })],
    grid: [props({ rowPadding: num(5), gridHorizontal: bool(true), gridHorizontalColor: col("#E3EAE5") })],
    total: [props({ totals: bool(true), backColor: col(C.verdeClaro), fontColor: col(C.verde), bold: bool(true) })],
  },
  visualContainerObjects: {
    ...vcoPanel("Líneas del PAA 2027", "Tabla con las seis columnas de referencia del Excel: identificador, tipo de necesidad, descripción, valor total, solicitante y mes estimado de inicio del proceso, ordenada por valor", "Columnas de referencia del archivo PAA · clic en un encabezado para ordenar · use el buscador y los filtros de arriba o haga clic en las gráficas"),
    stylePreset: [props({ name: str("None") })],
  },
});

visual("tablero", "chart_valor_mes", "columnChart", { x: 1296, y: 248, w: 592, h: 256 }, {
  query: {
    queryState: {
      Category: { projections: [pr(fCol(T, "Mes de inicio del proceso"), "Mes de inicio del proceso")] },
      Y: { projections: [pr(fMea(T, "Valor total PAA"), "Valor total")] },
      Tooltips: { projections: [pr(fMea(T, "Líneas PAA"), "Líneas")] },
    },
    sortDefinition: { sort: [{ field: fCol(T, "Mes de inicio del proceso"), direction: "Ascending" }], isDefaultSort: false },
  },
  objects: {
    dataPoint: [props({ defaultColor: col(C.verde) })],
    labels: [props({ show: bool(false) })],
    valueAxis: [props({ show: bool(true), gridlineShow: bool(true), labelDisplayUnits: lit("0D"), fontSize: num(9), showAxisTitle: bool(true), titleText: str("Valor (pesos)"), titleFontSize: num(10), titleColor: col(C.textoSuave) })],
    categoryAxis: [props({ fontSize: num(9), showAxisTitle: bool(true), titleText: str("Mes de inicio del proceso"), titleFontSize: num(10), titleColor: col(C.textoSuave) })],
  },
  visualContainerObjects: vcoPanel("Valor por mes de inicio del proceso", "Columnas del valor total por mes estimado de inicio del proceso", "Pase el cursor para ver el valor y las líneas · clic en una columna para filtrar la tabla"),
});
visual("tablero", "chart_etapa", "barChart", { x: 1296, y: 520, w: 592, h: 224 }, {
  query: {
    queryState: {
      Category: { projections: [pr(fCol(T, "Etapa"), "Etapa")] },
      Y: { projections: [pr(fMea(T, "Líneas PAA"), "Líneas")] },
      Tooltips: { projections: [pr(fMea(T, "Valor total PAA"), "Valor total")] },
    },
    sortDefinition: { sort: [{ field: fCol(T, "Etapa"), direction: "Ascending" }], isDefaultSort: false },
  },
  objects: {
    dataPoint: [props({ fill: colExpr(fMea(T, "Color de etapa")) }, { data: [{ dataViewWildcard: { matchingOption: 1 } }] })],
    labels: [props({ show: bool(true), fontSize: num(11), color: col(C.texto) })],
    categoryAxis: [props({ showAxisTitle: bool(true), titleText: str("Etapa del flujo"), titleFontSize: num(10), titleColor: col(C.textoSuave), fontSize: num(10) })],
  },
  visualContainerObjects: vcoPanel("Líneas por etapa del flujo", "Barras con el número de líneas en revisión, con ajuste solicitado y para comité de contratación", "Revisión → ajuste → comité · clic para filtrar"),
});
visual("tablero", "chart_tipo", "barChart", { x: 1296, y: 760, w: 592, h: 288 }, {
  query: {
    queryState: {
      Category: { projections: [pr(fCol(T, "Tipo de necesidad"), "Tipo de necesidad")] },
      Y: { projections: [pr(fMea(T, "Valor total PAA"), "Valor total")] },
      Tooltips: { projections: [pr(fMea(T, "Líneas PAA"), "Líneas"), pr(fMea(T, "% del valor total"), "% del valor")] },
    },
    sortDefinition: { sort: [{ field: fMea(T, "Valor total PAA"), direction: "Descending" }], isDefaultSort: false },
  },
  objects: { dataPoint: [props({ defaultColor: col(C.verde) })], labels: etiquetasMillones(), categoryAxis: [props({ showAxisTitle: bool(true), titleText: str("Tipo de necesidad"), titleFontSize: num(10), titleColor: col(C.textoSuave), fontSize: num(10) })] },
  visualContainerObjects: vcoPanel("Valor por tipo de necesidad", "Barras del valor total por tipo de necesidad, de mayor a menor", "Millones de pesos"),
});

// Bloque 2 (al desplazarse): estadísticas y gráficas.
texto("tablero", "titulo_estadisticas", { x: 32, y: 1072, w: 1400, h: 36 }, "Estadísticas del PAA 2027 · ¿dónde se concentra el valor?", { fontFamily: "Segoe UI Semibold", fontSize: "22px", color: C.verde });
barraAcento("tablero", "acento_estadisticas", { x: 32, y: 1112, w: 120, h: 4 }, C.oliva);

const topN = {
  name: "Filter" + h("topn-dependencias", 24),
  field: fCol(T, "Solicitante"),
  type: "TopN",
  filter: {
    Version: 2,
    From: [
      { Name: "subquery", Expression: { Subquery: { Query: {
        Version: 2,
        From: [{ Name: "l", Entity: T, Type: 0 }],
        Select: [{ Column: { Expression: { SourceRef: { Source: "l" } }, Property: "Solicitante" }, Name: "field" }],
        OrderBy: [{ Direction: 2, Expression: { Measure: { Expression: { SourceRef: { Source: "l" } }, Property: "Valor total PAA" } } }],
        Top: 10,
      } } }, Type: 2 },
      { Name: "l", Entity: T, Type: 0 },
    ],
    Where: [{ Condition: { In: { Expressions: [{ Column: { Expression: { SourceRef: { Source: "l" } }, Property: "Solicitante" } }], Table: { SourceRef: { Source: "subquery" } } } } }],
  },
};
visual("tablero", "chart_dependencias", "barChart", { x: 32, y: 1136, w: 920, h: 392 }, {
  query: {
    queryState: {
      Category: { projections: [pr(fCol(T, "Solicitante"), "Solicitante")] },
      Y: { projections: [pr(fMea(T, "Valor total PAA"), "Valor total")] },
      Tooltips: { projections: [pr(fMea(T, "Líneas PAA"), "Líneas")] },
    },
    sortDefinition: { sort: [{ field: fMea(T, "Valor total PAA"), direction: "Descending" }], isDefaultSort: false },
  },
  objects: { dataPoint: [props({ defaultColor: col(C.oliva) })], labels: etiquetasMillones(), categoryAxis: [props({ showAxisTitle: bool(true), titleText: str("Dependencia solicitante"), titleFontSize: num(10), titleColor: col(C.textoSuave), fontSize: num(10) })] },
  visualContainerObjects: vcoPanel("Top 10 dependencias por valor solicitado", "Barras doradas con las 10 dependencias que más valor solicitan", "Millones de pesos"),
}, { filterConfig: { filters: [topN] } });
visual("tablero", "chart_segmento", "barChart", { x: 968, y: 1136, w: 920, h: 392 }, {
  query: {
    queryState: {
      Category: { projections: [pr(fCol(T, "Segmento UNSPSC"), "Segmento UNSPSC")] },
      Y: { projections: [pr(fMea(T, "Valor total PAA"), "Valor total")] },
      Tooltips: { projections: [pr(fMea(T, "Líneas PAA"), "Líneas"), pr(fMea(T, "% del valor total"), "% del valor")] },
    },
    sortDefinition: { sort: [{ field: fMea(T, "Valor total PAA"), direction: "Descending" }], isDefaultSort: false },
  },
  objects: { dataPoint: [props({ defaultColor: col(C.verde) })], labels: etiquetasMillones(), categoryAxis: [props({ showAxisTitle: bool(true), titleText: str("Segmento UNSPSC"), titleFontSize: num(10), titleColor: col(C.textoSuave), fontSize: num(10) })] },
  visualContainerObjects: vcoPanel("Valor por segmento UNSPSC", "Barras del valor total por segmento del clasificador UNSPSC, de mayor a menor", "Segmento del primer código UNSPSC · millones de pesos"),
});
visual("tablero", "chart_rango", "lineClusteredColumnComboChart", { x: 32, y: 1544, w: 920, h: 392 }, {
  query: {
    queryState: {
      Category: { projections: [pr(fCol(T, "Rango de valor"), "Rango de valor de la línea")] },
      Y: { projections: [pr(fMea(T, "Líneas PAA"), "Número de líneas")] },
      Y2: { projections: [pr(fMea(T, "% del valor total"), "% del valor total")] },
    },
    sortDefinition: { sort: [{ field: fCol(T, "Rango de valor"), direction: "Ascending" }], isDefaultSort: false },
  },
  objects: {
    dataPoint: [
      props({ fill: col(C.verde) }, { metadata: qref(T, "Líneas PAA") }),
      props({ fill: col(C.oliva) }, { metadata: qref(T, "% del valor total") }),
    ],
    labels: [props({ show: bool(true), fontSize: num(10), color: col(C.texto) })],
    lineStyles: [props({ strokeWidth: num(3), showMarker: bool(true) })],
    legend: [props({ show: bool(true), position: str("Top"), fontSize: num(10) })],
    categoryAxis: [props({ showAxisTitle: bool(true), titleText: str("Rango de valor de la línea (pesos)"), titleFontSize: num(10), titleColor: col(C.textoSuave), fontSize: num(10) })],
    valueAxis: [props({
      show: bool(true), showAxisTitle: bool(true), titleText: str("Número de líneas"), titleFontSize: num(10), titleColor: col(C.textoSuave), gridlineShow: bool(true),
      secShow: bool(true), secShowAxisTitle: bool(true), secTitleText: str("% del valor total"), secTitleFontSize: num(10), secTitleColor: col(C.textoSuave),
    })],
  },
  visualContainerObjects: vcoPanel("¿Cuántas líneas hay por rango de valor y cuánto suman?", "Columnas con el número de líneas en cada rango de valor y línea con el porcentaje del valor total que suman; pocas líneas grandes concentran gran parte del valor", "Columnas verdes: cuántas líneas hay en el rango · Línea oliva: qué parte del valor total suman esas líneas"),
});
visual("tablero", "chart_unidad", "barChart", { x: 968, y: 1544, w: 920, h: 392 }, {
  query: {
    queryState: {
      Category: { projections: [pr(fCol(T, "Unidad de contratación"), "Unidad de contratación")] },
      Y: { projections: [pr(fMea(T, "Valor total PAA"), "Valor total")] },
      Tooltips: { projections: [pr(fMea(T, "Líneas PAA"), "Líneas")] },
    },
    sortDefinition: { sort: [{ field: fMea(T, "Valor total PAA"), direction: "Descending" }], isDefaultSort: false },
  },
  objects: { dataPoint: [props({ defaultColor: col(C.azul) })], labels: etiquetasMillones(), categoryAxis: [props({ showAxisTitle: bool(true), titleText: str("Unidad de contratación"), titleFontSize: num(10), titleColor: col(C.textoSuave), fontSize: num(10) })] },
  visualContainerObjects: vcoPanel("Valor por unidad de contratación", "Barras del valor total que gestionará cada unidad de contratación, de mayor a menor", "Millones de pesos · Sin asignar = la línea no trae unidad"),
});

// ---------- escritura ----------
function paginaJson(key) {
  const p = PAGINAS[key];
  const base = { $schema: SCHEMA_PAGE, name: p.id, displayName: p.nombre, displayOption: "FitToPage", height: 1080, width: 1920 };
  if (key === "tablero") Object.assign(base, { displayOption: process.env.VISTA_COMPLETA ? "FitToPage" : "FitToWidth", height: ALTO_TABLERO });
  base.objects = {
    background: [props({ color: col(key === "portada" ? C.verde : C.fondo), transparency: num(0) })],
  };
  return base;
}

function main() {
  // recursos
  rmSync(RR, { recursive: true, force: true });
  mkdirSync(RR, { recursive: true });
  copyFileSync(join(MARCA, "ALTA CALIDAD HORIZONTAL BLANCO.png"), join(RR, RECURSOS.logoAlta));
  copyFileSync(join(MARCA, "HORIZONTAL BLANCO.png"), join(RR, RECURSOS.logoBlanco));
  writeFileSync(join(RR, RECURSOS.fondo), svgFondo(), "utf8");
  const escudo = readFileSync(join(MARCA, "ESCUDO COLOR.png")).toString("base64");
  writeFileSync(join(RR, RECURSOS.emblema), svgEmblema(escudo), "utf8");

  // tema con nombre por hash del contenido (cache-busting automático)
  const t = tema();
  const nombreTema = `UCundinamarcaPAA-${h(JSON.stringify(t), 8)}.json`;
  t.name = nombreTema;
  writeJson(join(RR, nombreTema), t);

  // report.json: conserva el tema base del andamiaje y registra tema y recursos propios
  const reportPath = join(DEF, "report.json");
  const report = JSON.parse(readFileSync(reportPath, "utf8"));
  report.themeCollection.customTheme = { name: nombreTema, reportVersionAtImport: report.themeCollection.baseTheme.reportVersionAtImport, type: "RegisteredResources" };
  report.resourcePackages = report.resourcePackages.filter((r) => r.type !== "RegisteredResources");
  report.resourcePackages.push({
    name: "RegisteredResources",
    type: "RegisteredResources",
    items: [
      { name: nombreTema, path: nombreTema, type: "CustomTheme" },
      ...Object.values(RECURSOS).map((n) => ({ name: n, path: n, type: "Image" })),
    ],
  });
  report.objects = { outspacePane: [props({ expanded: bool(false) })] }; // panel de filtros contraído
  writeJson(reportPath, report);

  // páginas
  const pagesDir = join(DEF, "pages");
  rmSync(pagesDir, { recursive: true, force: true });
  const orden = Object.keys(PAGINAS);
  for (const key of orden) {
    const dir = join(pagesDir, PAGINAS[key].id);
    writeJson(join(dir, "page.json"), paginaJson(key));
    for (const v of visuals[key] || []) writeJson(join(dir, "visuals", v.name, "visual.json"), v);
  }
  writeJson(join(pagesDir, "pages.json"), { $schema: SCHEMA_PAGES, pageOrder: orden.map((k) => PAGINAS[k].id), activePageName: PAGINAS.portada.id });

  const total = orden.reduce((n, k) => n + (visuals[k] || []).length, 0);
  console.log(`Informe generado: ${orden.length} páginas, ${total} visuales, tema ${nombreTema}`);
}

main();
