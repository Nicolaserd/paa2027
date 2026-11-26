// Portada con efecto "liquid glass": panel de vidrio esmerilado (dibujado en el SVG de fondo)
// detrás del conteo por tipo de necesidad, y botón de vidrio. Solo toca la portada.
// Uso (desde la raíz del proyecto): node herramientas/portada_vidrio.mjs "<ruta del proyecto>"
// Se puede volver a ejecutar: reescribe el fondo SVG y reubica solo los visuales del conteo y el botón.
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { join } from "node:path";

const raiz = process.argv[2];
const report = join(raiz, "Lineas PAA 2027.Report");
const visuales = join(report, "definition", "pages", "3841caec25c45fa9cd0b", "visuals");
const fondoSvg = join(report, "StaticResources", "RegisteredResources", "portada-fondo20261125.svg");
const h = (s) => createHash("sha1").update(s).digest("hex").slice(0, 20);
const ruta = (key) => join(visuales, h(`portada/${key}`), "visual.json");
const lit = (v) => ({ expr: { Literal: { Value: v } } });
const colr = (hex) => ({ solid: { color: lit(`'${hex}'`) } });
const editar = (key, fn) => {
  const f = ruta(key);
  if (!existsSync(f)) throw new Error("no existe el visual " + key);
  const j = JSON.parse(readFileSync(f, "utf8"));
  fn(j);
  writeFileSync(f, JSON.stringify(j, null, 2) + "\n", "utf8");
};
const pos = (j, p) => Object.assign(j.position, p);
const texto = (j, px, color) => j.visual.objects.general[0].properties.paragraphs.forEach((pa) =>
  pa.textRuns.forEach((r) => { r.textStyle.fontSize = px; if (color) r.textStyle.color = color; }));

// ---------- geometría ----------
const PANEL = { x: 64, y: 464, w: 1104, h: 440, r: 36 };
const BOTON = { x: 64, y: 928, w: 260, h: 56, r: 14 };
const HERO = { x: 96, w: 300 };
const GRID = { x: 456, y: 528, cw: 328, ch: 172, gx: 32, gy: 16 };
const NOMBRE_H = 56;

// ---------- SVG de fondo con vidrio líquido ----------
function rectRedondo(p) { return `x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" rx="${p.r}"`; }
function vidrio(id, p, opts = {}) {
  const m = 40; // margen de la región del filtro
  return `
<filter id="esm_${id}" filterUnits="userSpaceOnUse" x="${p.x - m}" y="${p.y - m}" width="${p.w + 2 * m}" height="${p.h + 2 * m}">
  <feGaussianBlur in="SourceGraphic" stdDeviation="${opts.blur ?? 16}" result="b"/>
  <feTurbulence type="fractalNoise" baseFrequency="0.006 0.011" numOctaves="2" seed="${opts.seed ?? 4}" result="n"/>
  <feDisplacementMap in="b" in2="n" scale="${opts.dist ?? 46}" xChannelSelector="R" yChannelSelector="G"/>
</filter>
<clipPath id="clip_${id}"><rect ${rectRedondo(p)}/></clipPath>`;
}
function capaVidrio(id, p, opts = {}) {
  return `
<rect ${rectRedondo(p)} fill="#001A10" opacity="${opts.sombra ?? 0.38}" filter="url(#sombra)" transform="translate(0 16)"/>
<g clip-path="url(#clip_${id})">
  <use href="#escena" xlink:href="#escena" filter="url(#esm_${id})"/>
  <rect ${rectRedondo(p)} fill="#FFFFFF" fill-opacity="${opts.velo ?? 0.07}"/>
  <rect ${rectRedondo(p)} fill="url(#reflejo)"/>
  <rect class="barrido_${id}" x="${p.x - 420}" y="${p.y - 40}" width="300" height="${p.h + 80}" fill="url(#destello)"/>
</g>
<rect ${rectRedondo(p)} fill="none" stroke="url(#borde)" stroke-width="1.6"/>
<path d="M ${p.x + p.r} ${p.y + 1.4} H ${p.x + p.w - p.r}" stroke="#FFFFFF" stroke-opacity=".55" stroke-width="1.2" stroke-linecap="round"/>`;
}

function svgFondo() {
  const anillos = Array.from({ length: 11 }, (_, i) => 380 + i * 70)
    .map((r, i) => `<circle cx="1530" cy="540" r="${r}" fill="none" stroke="#FFFFFF" stroke-opacity="${(0.07 - i * 0.004).toFixed(3)}" stroke-width="1.2" stroke-dasharray="${i % 2 ? "2 10" : "14 8"}" class="${i % 2 ? "g1" : "g2"}"/>`)
    .join("");
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1920" height="1080" viewBox="0 0 1920 1080">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#005433"/><stop offset=".55" stop-color="#00482B"/><stop offset="1" stop-color="#00321E"/></linearGradient>
<radialGradient id="luz" cx="1530" cy="540" r="620" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#1E7A52" stop-opacity=".55"/><stop offset="1" stop-color="#00482B" stop-opacity="0"/></radialGradient>
<radialGradient id="luz2" cx="380" cy="640" r="520" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#3E9A70" stop-opacity=".45"/><stop offset="1" stop-color="#00482B" stop-opacity="0"/></radialGradient>
<linearGradient id="cinta" x1="0" x2="1"><stop offset="0" stop-color="#1E6B48"/><stop offset=".5" stop-color="#A9C4B6"/><stop offset="1" stop-color="#1E6B48"/></linearGradient>
<linearGradient id="reflejo" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".20"/><stop offset=".35" stop-color="#FFFFFF" stop-opacity=".05"/><stop offset="1" stop-color="#FFFFFF" stop-opacity=".02"/></linearGradient>
<linearGradient id="borde" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".80"/><stop offset=".3" stop-color="#FFFFFF" stop-opacity=".18"/><stop offset=".7" stop-color="#FFFFFF" stop-opacity=".08"/><stop offset="1" stop-color="#FFFFFF" stop-opacity=".45"/></linearGradient>
<linearGradient id="destello" x1="0" x2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0"/><stop offset=".5" stop-color="#FFFFFF" stop-opacity=".16"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
<filter id="sombra" x="-20%" y="-20%" width="140%" height="160%"><feGaussianBlur stdDeviation="22"/></filter>
<g id="escena">
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect class="luz" width="1920" height="1080" fill="url(#luz)"/>
  <rect class="luz2" width="1920" height="1080" fill="url(#luz2)"/>
  <g>${anillos}</g>
  <g class="diag" stroke="#FFFFFF" stroke-opacity=".06" stroke-width="2">
    <line x1="-40" y1="1080" x2="320" y2="720"/><line x1="20" y1="1080" x2="380" y2="720"/><line x1="80" y1="1080" x2="440" y2="720"/>
  </g>
</g>
${vidrio("panel", PANEL)}
${vidrio("boton", BOTON, { blur: 10, dist: 24, seed: 9 })}
</defs>
<style>
.g1{transform-origin:1530px 540px;animation:giro 140s linear infinite}
.g2{transform-origin:1530px 540px;animation:giro 200s linear infinite reverse}
.luz{animation:respira 7s ease-in-out infinite}
.luz2{animation:deriva 11s ease-in-out infinite alternate}
.diag{animation:desliza 9s ease-in-out infinite alternate}
.barrido_panel{animation:barrido 8s cubic-bezier(.45,0,.2,1) 1s infinite}
.barrido_boton{animation:barridoBoton 8s cubic-bezier(.45,0,.2,1) 1.6s infinite}
@keyframes giro{to{transform:rotate(360deg)}}
@keyframes respira{0%,100%{opacity:.75}50%{opacity:1}}
@keyframes deriva{from{transform:translate(0,0)}to{transform:translate(90px,-40px)}}
@keyframes desliza{from{transform:translateX(0)}to{transform:translateX(26px)}}
@keyframes barrido{0%{transform:translateX(0) skewX(-18deg)}55%,100%{transform:translateX(1620px) skewX(-18deg)}}
@keyframes barridoBoton{0%{transform:translateX(0) skewX(-18deg)}35%,100%{transform:translateX(760px) skewX(-18deg)}}
</style>
<use href="#escena" xlink:href="#escena"/>
${capaVidrio("panel", PANEL)}
${capaVidrio("boton", BOTON, { velo: 0.12, sombra: 0.3 })}
<rect y="1068" width="1920" height="12" fill="url(#cinta)"/>
</svg>`;
}
writeFileSync(fondoSvg, svgFondo(), "utf8");

// ---------- visuales de la portada ----------
const CLARO = "#E4EFE8";
// título de la franja, dentro del vidrio
editar("titulo_conteo", (j) => { pos(j, { x: PANEL.x + 32, y: PANEL.y + 24, width: 640, height: 36 }); texto(j, "22px", "#D7E6DD"); });

// total: cifra protagonista a la izquierda
editar("conteo_nombre_0", (j) => { pos(j, { x: HERO.x + 16, y: GRID.y, width: HERO.w - 16, height: 36 }); texto(j, "22px", CLARO); });
editar("conteo_numero_0", (j) => {
  pos(j, { x: HERO.x, y: GRID.y + 44, width: HERO.w, height: 220 });
  j.visual.objects.value[0].properties.fontSize = lit("110D");
  j.visual.objects.label[0].properties.fontSize = lit("18D");
});

// 4 tipos en cuadrícula 2 x 2
for (let i = 1; i <= 4; i++) {
  const c = (i - 1) % 2, f = Math.floor((i - 1) / 2);
  const x = GRID.x + c * (GRID.cw + GRID.gx);
  const y = GRID.y + f * (GRID.ch + GRID.gy);
  editar(`conteo_nombre_${i}`, (j) => { pos(j, { x: x + 16, y, width: GRID.cw - 16, height: NOMBRE_H }); texto(j, "21px", CLARO); });
  editar(`conteo_numero_${i}`, (j) => {
    pos(j, { x, y: y + NOMBRE_H, width: GRID.cw, height: GRID.ch - NOMBRE_H });
    j.visual.objects.value[0].properties.fontSize = lit("52D");
    j.visual.objects.label[0].properties.fontSize = lit("14D");
  });
}

// líneas finas: total | cuadrícula, columna | columna, fila / fila
const linea = (key, p) => editar(key, (j) => {
  pos(j, p);
  j.visual.objects.fill[0].properties.fillColor = colr("#FFFFFF");
  j.visual.objects.fill[0].properties.transparency = lit("72D");
});
linea("conteo_division_1", { x: 424, y: GRID.y, width: 1, height: 2 * GRID.ch + GRID.gy });
linea("conteo_division_2", { x: GRID.x + GRID.cw + GRID.gx / 2, y: GRID.y, width: 1, height: 2 * GRID.ch + GRID.gy });
linea("conteo_division_3", { x: GRID.x, y: GRID.y + GRID.ch + GRID.gy / 2, width: 2 * GRID.cw + GRID.gx, height: 1 });
const sobra = join(visuales, h("portada/conteo_division_4"));
if (existsSync(sobra)) rmSync(sobra, { recursive: true });

// botón de vidrio: relleno transparente (el vidrio está en el fondo), texto blanco
editar("btn_explorar", (j) => {
  pos(j, { x: BOTON.x, y: BOTON.y, width: BOTON.w, height: BOTON.h });
  const o = j.visual.objects;
  for (const e of o.fill) {
    const sel = e.selector?.id;
    if (sel === "default") { e.properties.fillColor = colr("#FFFFFF"); e.properties.transparency = lit("100D"); }
    if (sel === "hover") { e.properties.fillColor = colr("#FFFFFF"); e.properties.transparency = lit("84D"); }
  }
  for (const e of o.text) {
    const sel = e.selector?.id;
    if (sel === "default" || sel === "hover") e.properties.fontColor = colr("#FFFFFF");
  }
  for (const e of o.icon) {
    const sel = e.selector?.id;
    if (sel === "default" || sel === "hover") e.properties.lineColor = colr("#FFFFFF");
  }
  for (const e of o.outline) { if (!e.selector) e.properties.show = lit("false"); }
});

console.log("portada con vidrio liquido lista");
