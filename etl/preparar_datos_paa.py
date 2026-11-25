"""Prepara el Excel de líneas nuevas del PAA para el informe de Power BI.

Lee el .xls exportado (hoja única "tabla_output_values"), limpia y tipa los
valores y escribe data/paa_lineas.csv, que es lo que importa el modelo semántico
"Lineas PAA 2027".

Uso (desde la raíz del proyecto):
    .venv\\Scripts\\python.exe etl\\preparar_datos_paa.py                 # toma el .xls más reciente de data/
    .venv\\Scripts\\python.exe etl\\preparar_datos_paa.py "data\\archivo.xls"

Después de ejecutarlo, en Power BI Desktop: Inicio > Actualizar.

Notas sobre el origen:
- Las 6 celdas de encabezado con relleno verde (#339966) del Excel marcan las
  columnas de referencia: Identificador, Tipo de Necesidad, Descripción,
  Valor Total, Nombre del solicitante y Fecha Estimada de Inicio del Proceso
  (mes). El script las detecta y lo informa; el informe las usa como columnas
  principales de la tabla.
- Se descartan columnas vacías o sin valor analítico (teléfono y correo del
  responsable, fecha de creación, número de proyecto).
"""
from __future__ import annotations

import csv
import sys
import unicodedata
from pathlib import Path

import xlrd

RAIZ = Path(__file__).resolve().parent.parent
CARPETA_DATOS = RAIZ / "data"
SALIDA = CARPETA_DATOS / "paa_lineas.csv"

MESES = ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO",
         "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"]

# Encabezados esperados en el Excel de origen (se buscan sin tildes ni mayúsculas).
COLUMNAS_ORIGEN = {
    "id": "identificador",
    "justificacion": "justificacion de la necesidad a incluir en el paa",
    "tipo": "tipo de necesidad:",
    "unspsc": "codigo unspsc",
    "descripcion": "descripcion de la necesidad",
    "fecha_contratacion": "fecha estimada de inicio del proceso de contratacion",
    "duracion": "duracion estimada del contrato (numero)",
    "unidad_duracion": "unidad de duracion estimada del contrato",
    "fuente": "fuentes de recursos",
    "valor": "valor total de la necesidad:",
    "solicitante": "nombre del solicitante:",
    "mes_proceso": "fecha estimada de inicio del proceso.",
    "estado": "estado",
    "modalidad": "modalidad de seleccion",
    "vigencias_futuras": "¿se requiere para vigencias futuras?",
    "unidad_contratacion": "unidad de contratacion (referencia)",
    "tarea": "nombre de tarea",
}

# Unificación de nombres de dependencias escritos de dos formas en el origen.
SOLICITANTE_UNIFICADO = {
    "APOYO ACADÉMICO": "APOYO ACADEMICO",
}

# Etapa del flujo de aprobación (Nombre de Tarea) -> etiqueta corta y orden.
ETAPAS = {
    "revision de la necesidad por administrador paa proyectos": ("En revisión", 1),
    "ajustar necesidad por solicitud de administrador paa": ("Ajuste solicitado", 2),
    "presentacion de necesidad ante comite de contratacion (inversion)": ("Para comité de contratación", 3),
}

# Segmentos UNSPSC (dos primeros dígitos del código) usados en compras públicas.
SEGMENTOS_UNSPSC = {
    "10": "Material vivo vegetal y animal", "11": "Material mineral, textil y no comestible",
    "12": "Material químico", "14": "Papel y productos de papel", "15": "Combustibles y lubricantes",
    "20": "Maquinaria de minería y perforación", "21": "Maquinaria agrícola y forestal",
    "22": "Maquinaria para construcción", "23": "Maquinaria industrial",
    "24": "Manejo y almacenamiento de materiales", "25": "Vehículos y accesorios",
    "26": "Maquinaria de generación de energía", "27": "Herramientas y maquinaria general",
    "30": "Componentes y suministros de construcción", "31": "Componentes de fabricación",
    "32": "Componentes electrónicos", "39": "Suministros eléctricos e iluminación",
    "40": "Distribución y acondicionamiento de sistemas", "41": "Equipos de laboratorio",
    "42": "Equipo médico", "43": "Tecnologías de información y telecomunicaciones",
    "44": "Equipos y suministros de oficina", "45": "Equipos de imprenta, fotografía y audiovisuales",
    "46": "Equipos de defensa y seguridad", "47": "Equipos y suministros de limpieza",
    "48": "Equipos para servicio de alimentos", "49": "Equipos deportivos y recreativos",
    "50": "Alimentos y bebidas", "51": "Medicamentos y productos farmacéuticos",
    "52": "Artículos domésticos", "53": "Ropa y accesorios", "55": "Publicaciones impresas",
    "56": "Muebles y mobiliario", "60": "Instrumentos musicales y material educativo",
    "70": "Servicios agrícolas y ambientales", "72": "Servicios de construcción y mantenimiento",
    "73": "Servicios de producción industrial", "76": "Servicios de limpieza",
    "77": "Servicios medioambientales", "78": "Servicios de transporte y almacenaje",
    "80": "Servicios de gestión y profesionales", "81": "Servicios de ingeniería, investigación y tecnología",
    "82": "Servicios editoriales, de diseño y artes gráficas", "83": "Servicios públicos",
    "84": "Servicios financieros y de seguros", "85": "Servicios de salud",
    "86": "Servicios educativos y de formación", "90": "Servicios de viajes, alimentación y alojamiento",
    "91": "Servicios personales y domésticos", "92": "Servicios de defensa y orden público",
    "93": "Servicios políticos y cívicos", "94": "Organizaciones y clubes",
    "95": "Terrenos, edificios y estructuras",
}

CAMPOS_SALIDA = [
    "Identificador", "Número de línea", "Tipo de necesidad", "Origen de la inversión",
    "Es contratación de personal", "Descripción de la necesidad", "Justificación",
    "Código UNSPSC", "Segmento UNSPSC", "Fecha estimada de contratación",
    "Duración", "Unidad de duración", "Duración en meses", "Fuente de recursos",
    "Valor de la necesidad", "Solicitante", "Mes de inicio del proceso", "Número de mes del proceso",
    "Estado", "Modalidad de selección", "Requiere vigencias futuras",
    "Unidad de contratación", "Etapa", "Orden de etapa", "Tarea actual",
    "Rango de valor", "Orden de rango de valor",
]

# Rangos de valor (límite superior exclusivo, en pesos) para la gráfica de distribución.
RANGOS_VALOR = [
    (10_000_000, "Menos de 10 millones"),
    (50_000_000, "10 a 50 millones"),
    (100_000_000, "50 a 100 millones"),
    (500_000_000, "100 a 500 millones"),
    (1_000_000_000, "500 a 1.000 millones"),
    (float("inf"), "Más de 1.000 millones"),
]


def rango_valor(valor: int) -> tuple[str, int]:
    for orden, (limite, etiqueta) in enumerate(RANGOS_VALOR, start=1):
        if valor < limite:
            return etiqueta, orden
    return RANGOS_VALOR[-1][1], len(RANGOS_VALOR)


def normalizar(texto: str) -> str:
    """Minúsculas, sin tildes y sin espacios sobrantes (para comparar encabezados)."""
    sin_tildes = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode("ascii")
    return " ".join(sin_tildes.lower().split())


def limpiar(texto) -> str:
    return " ".join(str(texto).replace("\xa0", " ").split())


def archivo_mas_reciente() -> Path:
    candidatos = sorted(CARPETA_DATOS.glob("*.xls"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not candidatos:
        sys.exit(f"No hay archivos .xls en {CARPETA_DATOS}")
    return candidatos[0]


def main() -> None:
    origen = Path(sys.argv[1]) if len(sys.argv) > 1 else archivo_mas_reciente()
    libro = xlrd.open_workbook(str(origen), formatting_info=True)
    hoja = libro.sheet_by_index(0)

    encabezados = {normalizar(str(hoja.cell_value(0, c))): c for c in range(hoja.ncols)}
    faltantes = [n for n in COLUMNAS_ORIGEN.values() if normalizar(n) not in encabezados]
    if faltantes:
        sys.exit(f"Faltan columnas en {origen.name}: {faltantes}")
    col = {k: encabezados[normalizar(v)] for k, v in COLUMNAS_ORIGEN.items()}

    coloreadas = []
    for c in range(hoja.ncols):
        fondo = libro.xf_list[hoja.cell_xf_index(0, c)].background
        if fondo.fill_pattern and fondo.pattern_colour_index not in (64, 65):
            coloreadas.append(limpiar(hoja.cell_value(0, c)))

    filas = []
    for r in range(1, hoja.nrows):
        v = lambda k: limpiar(hoja.cell_value(r, col[k]))  # noqa: E731
        identificador = v("id")
        if not identificador:
            continue

        fecha = v("fecha_contratacion").replace("/", "-")  # 2027/02/01 -> 2027-02-01
        duracion = int(float(v("duracion") or 0))
        unidad = v("unidad_duracion").upper()
        meses = round(duracion / 30, 1) if unidad.startswith("DIA") else float(duracion)

        mes_proceso = v("mes_proceso").upper()
        tipo = v("tipo")
        tipo_norm = normalizar(tipo)
        unspsc = v("unspsc").replace(" ", "")
        segmento = SEGMENTOS_UNSPSC.get(unspsc[:2], "Otro segmento") if unspsc else "Sin código"
        tarea = v("tarea")
        etapa, orden = ETAPAS.get(normalizar(tarea), (tarea or "Sin etapa", 9))
        solicitante = v("solicitante").upper()
        solicitante = SOLICITANTE_UNIFICADO.get(solicitante, solicitante)
        valor = int(v("valor").replace(".", "").replace(",", "") or 0)
        rango, orden_rango = rango_valor(valor)

        filas.append({
            "Identificador": identificador,
            "Número de línea": int(identificador.rsplit("-", 1)[-1]),
            "Tipo de necesidad": tipo,
            "Origen de la inversión": "Fondos de inversión" if "fondos" in tipo_norm else "Proyectos de inversión",
            "Es contratación de personal": "Sí" if "contratacion de personal" in tipo_norm else "No",
            "Descripción de la necesidad": v("descripcion"),
            "Justificación": v("justificacion"),
            "Código UNSPSC": unspsc.replace(";", "; "),
            "Segmento UNSPSC": segmento,
            "Fecha estimada de contratación": fecha,
            "Duración": duracion,
            "Unidad de duración": "Días" if unidad.startswith("DIA") else "Meses",
            "Duración en meses": meses,
            "Fuente de recursos": v("fuente").replace(" ; ", " + "),
            "Valor de la necesidad": valor,
            "Solicitante": solicitante,
            "Mes de inicio del proceso": mes_proceso.capitalize(),
            "Número de mes del proceso": MESES.index(mes_proceso) + 1 if mes_proceso in MESES else 13,
            "Estado": v("estado"),
            "Modalidad de selección": v("modalidad"),
            "Requiere vigencias futuras": "Sí" if normalizar(v("vigencias_futuras")) == "si" else "No",
            "Unidad de contratación": v("unidad_contratacion") or "Sin asignar",
            "Etapa": etapa,
            "Orden de etapa": orden,
            "Tarea actual": tarea,
            "Rango de valor": rango,
            "Orden de rango de valor": orden_rango,
        })

    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    with SALIDA.open("w", encoding="utf-8", newline="") as f:
        escritor = csv.DictWriter(f, fieldnames=CAMPOS_SALIDA, quoting=csv.QUOTE_MINIMAL)
        escritor.writeheader()
        escritor.writerows(filas)

    total = sum(f["Valor de la necesidad"] for f in filas)
    print(f"Origen: {origen.name}")
    print(f"Columnas de referencia (encabezado coloreado): {', '.join(coloreadas) or 'ninguna'}")
    print(f"Líneas exportadas: {len(filas)} | Valor total: {total:,.0f}".replace(",", "."))
    print(f"Salida: {SALIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
