# backend/app/services/reporte_service.py
"""
ReporteService — tres flujos principales:

  1. exportar_predefinido  → reutiliza DashboardService y serializa a archivo.
  2. generar_reporte_dinamico → consulta SQL segura basada en whitelist + taller_id.
  3. interpretar_prompt_ia → Gemini convierte lenguaje natural en parámetros de reporte.
  4. _generar_archivo (privado) → BytesIO para xlsx / csv / pdf.
"""
import io
import json
import os
from datetime import datetime
from typing import Any, Optional

import pandas as pd
import google.generativeai as genai
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.reportes import ENTIDADES_PERMITIDAS, FORMATOS_PERMITIDOS
from app.services.dashboard_service import DashboardService

# ── Mapa de KPI id → método del DashboardService ──────────────────────────────
_KPI_TITULOS = {
    1:  "KPI 1 - Tiempo Promedio de Resolución",
    2:  "KPI 2 - Tasa de Aceptación por Sucursal",
    3:  "KPI 3 - Tiempo Promedio de Asignación",
    4:  "KPI 4 - Tiempo Promedio de Llegada",
    5:  "KPI 5 - Tipos de Incidencia",
    6:  "KPI 6 - Ranking de Talleres",
    7:  "KPI 7 - Mapa de Calor de Emergencias",
    8:  "KPI 8 - Tasa de Cancelados por Mes",
    9:  "KPI 9 - Puntualidad (A Tiempo vs Atrasado)",
    10: "KPI 10 - Precisión de Estimación de Costos",
    11: "KPI 11 - Ranking de Mecánicos",
}


class ReporteService:

    def __init__(self, session: AsyncSession):
        self.session = session

    # ── 1. Exportar KPI Predefinido ───────────────────────────────────────────

    async def exportar_predefinido(
        self,
        kpi_id: int,
        formato: str,
        taller_id: Optional[int],
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
    ) -> tuple[io.BytesIO, str, str]:
        """
        Devuelve (buffer, extensión, nombre_archivo).
        Lanza ValueError para kpi_id inválido o formato inválido.
        Lanza PermissionError si KPI 11 se solicita sin taller_id.
        """
        if formato not in FORMATOS_PERMITIDOS:
            raise ValueError(f"Formato '{formato}' no soportado.")
        if kpi_id not in _KPI_TITULOS:
            raise ValueError(f"KPI {kpi_id} no existe. Rango válido: 1-11.")
        if kpi_id == 11 and taller_id is None:
            raise PermissionError("KPI 11 (ranking de mecánicos) es exclusivo para ADMIN_TALLER.")

        svc = DashboardService(self.session)

        # Despachar al método correcto según el id del KPI
        if kpi_id == 1:
            data = await svc.kpi1_tiempo_espera(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 2:
            data = await svc.kpi2_tasa_aceptacion(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 3:
            data = await svc.kpi3_tiempo_asignacion(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 4:
            data = await svc.kpi4_tiempo_llegada(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 5:
            data = await svc.kpi5_tipos_incidencia(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 6:
            data = await svc.kpi6_ranking_talleres(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 7:
            data = await svc.kpi7_mapa_calor(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 8:
            data = await svc.kpi8_tasa_cancelados(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 9:
            data = await svc.kpi9_puntualidad(fecha_inicio, fecha_fin, taller_id)
        elif kpi_id == 10:
            data = await svc.kpi10_precision_costos(fecha_inicio, fecha_fin, taller_id)
        else:  # 11
            data = await svc.kpi11_ranking_mecanicos(taller_id, fecha_inicio, fecha_fin)

        df = pd.DataFrame([data]) if isinstance(data, dict) else pd.DataFrame(data or [])

        titulo = _KPI_TITULOS[kpi_id]
        buf, ext = self._generar_archivo(df, formato, titulo)
        nombre = f"kpi{kpi_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{ext}"
        return buf, ext, nombre

    # ── 2. Reporte Dinámico Relacional Seguro ────────────────────────────────

    async def generar_reporte_dinamico(
        self,
        tabla_base: str,
        tablas_relacionadas: list[str],
        columnas: list[str],
        filtros: dict[str, Any],
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        formato: str,
        taller_id: Optional[int],
    ) -> tuple[io.BytesIO, str, str]:
        """
        Construye y ejecuta una consulta SQL relacional SEGURA:
          - tabla_base y tablas_relacionadas provienen del whitelist.
          - JOINs son expresiones hardcodeadas del whitelist (nunca interpoladas).
          - Columnas en formato 'ENTIDAD.alias' validadas contra el whitelist.
          - Filtros aplicados como bound parameters (nunca interpolados).
          - taller_id aplica automáticamente la restricción multi-tenant.

        Devuelve (buffer, extensión, nombre_archivo).
        """
        base_meta = ENTIDADES_PERMITIDAS.get(tabla_base)
        if not base_meta:
            raise ValueError(
                f"Tabla base '{tabla_base}' no permitida. "
                f"Opciones: {sorted(ENTIDADES_PERMITIDAS.keys())}"
            )

        # ── Validar JOINs disponibles ─────────────────────────────────────────
        available_joins: dict[str, str] = base_meta.get("joins", {})
        for rel in tablas_relacionadas:
            if rel not in ENTIDADES_PERMITIDAS:
                raise ValueError(f"Tabla relacionada '{rel}' no existe.")
            if rel not in available_joins:
                raise ValueError(
                    f"No hay JOIN definido entre '{tabla_base}' y '{rel}'. "
                    f"JOINs disponibles desde '{tabla_base}': {list(available_joins.keys())}"
                )

        # ── Mapa combinado de columnas ────────────────────────────────────────
        # Clave: "ENTIDAD.alias"  →  valor: "expresión SQL del whitelist"
        all_entities = [tabla_base, *tablas_relacionadas]
        combined_col_map: dict[str, str] = {}
        for entity in all_entities:
            for alias, expr in ENTIDADES_PERMITIDAS[entity]["columnas"].items():
                combined_col_map[f"{entity}.{alias}"] = expr

        # Columnas vacías → todas las disponibles
        if not columnas:
            columnas = list(combined_col_map.keys())

        # Validar columnas
        invalidas = [c for c in columnas if c not in combined_col_map]
        if invalidas:
            raise ValueError(
                f"Columnas no válidas: {invalidas}. "
                f"Use formato 'ENTIDAD.alias'. Disponibles: {list(combined_col_map.keys())}"
            )

        # Validar filtros (solo sobre columnas de tabla_base para simplificar)
        base_col_map: dict[str, str] = base_meta["columnas"]
        filtros_invalidos = [k for k in filtros if k not in base_col_map]
        if filtros_invalidos:
            raise ValueError(
                f"Filtros no permitidos: {filtros_invalidos}. "
                f"Solo se puede filtrar por columnas de la tabla base '{tabla_base}': "
                f"{list(base_col_map.keys())}"
            )

        # Normalizar campos 'estado' a mayúsculas (enums PG son case-sensitive)
        filtros = {
            k: v.upper() if isinstance(v, str) and "estado" in k else v
            for k, v in filtros.items()
        }

        # ── SELECT ────────────────────────────────────────────────────────────
        # AS alias = "entidad_alias" en minúsculas (unambiguous y user-friendly)
        select_exprs = [
            f"{combined_col_map[col]} AS {col.replace('.', '_').lower()}"
            for col in columnas
        ]
        select_clause = ", ".join(select_exprs)

        # ── FROM + JOINs ──────────────────────────────────────────────────────
        from_parts = [base_meta["from_clause"]]
        for rel in tablas_relacionadas:
            from_parts.append(available_joins[rel])
        from_clause = " ".join(from_parts)

        # ── WHERE ─────────────────────────────────────────────────────────────
        where_parts: list[str] = [base_meta["base_where"]]
        params: dict[str, Any] = {}

        if taller_id is not None:
            where_parts.append(base_meta["taller_filter"])
            params["taller_id"] = taller_id

        date_field = base_meta.get("date_field")
        if fecha_inicio and date_field:
            where_parts.append(f"{date_field} >= :fecha_inicio")
            params["fecha_inicio"] = fecha_inicio
        if fecha_fin and date_field:
            where_parts.append(f"{date_field} <= :fecha_fin")
            params["fecha_fin"] = fecha_fin

        for idx, (alias, valor) in enumerate(filtros.items()):
            col_expr = base_col_map[alias]
            param_name = f"f_{idx}"
            where_parts.append(f"{col_expr} = :{param_name}")
            params[param_name] = valor

        where_clause = " AND ".join(where_parts)

        sql = (
            f"SELECT {select_clause}"
            f" FROM {from_clause}"
            f" WHERE {where_clause}"
        )

        result = await self.session.execute(text(sql), params)
        rows = result.mappings().all()

        col_aliases = [col.replace(".", "_").lower() for col in columnas]
        df = (
            pd.DataFrame([dict(r) for r in rows])
            if rows
            else pd.DataFrame(columns=col_aliases)
        )

        titulo = f"Reporte {tabla_base.capitalize()}"
        if tablas_relacionadas:
            titulo += " + " + " + ".join(r.capitalize() for r in tablas_relacionadas)
        buf, ext = self._generar_archivo(df, formato, titulo)
        nombre = f"reporte_{tabla_base.lower()}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{ext}"
        return buf, ext, nombre

    # ── 3. Interpretar Prompt con Gemini ──────────────────────────────────────

    async def interpretar_prompt_ia(
        self, prompt: str, formato_override: str = "xlsx"
    ) -> dict:
        """
        Llama a Gemini con el prompt del usuario y devuelve un dict validado
        con los parámetros para generar_reporte_dinamico (formato relacional):
          {tabla_base, tablas_relacionadas, columnas, filtros, fecha_inicio, fecha_fin, formato}

        columnas vienen en formato 'ENTIDAD.alias', ya normalizadas y validadas contra
        el whitelist de ENTIDADES_PERMITIDAS. Hallucinations de la IA son silenciosamente
        descartadas antes de que cualquier valor llegue al SQL.

        Lanza ValueError si la IA devuelve JSON inválido o tabla_base desconocida.
        """
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY no está configurada en el entorno.")

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            "gemini-2.5-flash",
            generation_config={"response_mime_type": "application/json"},
        )

        # Contexto de negocio por entidad (para el system prompt)
        _contexto_negocio = {
            "SOLICITUDES":  "Solicitudes de emergencia vehicular (llamados SOS de clientes). Tabla principal del negocio.",
            "MECANICOS":    "Mecánicos y empleados de los talleres. Capital humano que atiende emergencias.",
            "DIAGNOSTICOS": "Diagnósticos / Tipos de servicio y fallas generados por IA. Gravedad, categoría (categoria_incidencia) y costo estimado.",
            "ASIGNACIONES": "Registro de qué mecánico atendió qué solicitud. Tiempos y puntualidad.",
            "PUJAS":        "Cotizaciones del marketplace: talleres compitiendo por atender una solicitud.",
            "ORDENES":      "Órdenes de trabajo generadas al aceptar una solicitud. Puente entre solicitud y pago.",
            "PAGOS":        "DINERO y facturación. monto_total=cobro al cliente | monto_taller=ganancia del taller | comision=ganancia de la plataforma.",
            "SUCURSALES":   "Sucursales / puntos de atención de los talleres. Cada sucursal pertenece a un taller (taller_id).",
        }
        entidades_desc = "\n".join(
            f"  {name} — {_contexto_negocio[name]}\n"
            f"    Columnas: [{', '.join(meta['columnas'].keys())}]\n"
            f"    Puede cruzar con (tablas_relacionadas): "
            f"{', '.join(meta.get('joins', {}).keys()) or 'ninguna'}"
            for name, meta in ENTIDADES_PERMITIDAS.items()
        )

        system_prompt = f"""
Eres FIXO-BI, motor de inteligencia de negocio para una plataforma boliviana de asistencia vehicular.
Tu única tarea: convertir la solicitud del usuario en un JSON de parámetros para un reporte.

═══════════════════════════════════════════════
ENTIDADES, COLUMNAS Y CRUCES DISPONIBLES:
═══════════════════════════════════════════════
{entidades_desc}

═══════════════════════════════════════════════
GLOSARIO FINANCIERO — tabla PAGOS:
═══════════════════════════════════════════════
• monto_total  → dinero total cobrado al cliente
• monto_taller → ganancia/ingreso neto del taller (lo que retiene el taller)
• comision     → comisión que se queda la plataforma FIXO
• metodo_pago  → medio: efectivo, tarjeta, QR, etc.

═══════════════════════════════════════════════
GLOSARIO DE ESTADOS — usa SIEMPRE estos valores exactos en filtros:
═══════════════════════════════════════════════
• SOLICITUDES.estado  → "PENDIENTE" | "EN_PROCESO" | "FINALIZADO" | "CANCELADO"
  — completadas/terminadas → "FINALIZADO"
• ASIGNACIONES.estado → "PENDIENTE" | "EN_CAMINO" | "COMPLETADA" | "CANCELADA"
  — completadas/terminadas → "COMPLETADA"
• PUJAS.estado        → "PENDIENTE" | "ACEPTADA" | "RECHAZADA"
  — ganadoras/aceptadas   → "ACEPTADA"
• ORDENES.estado      → "PENDIENTE" | "EN_PROCESO" | "COMPLETADA" | "CANCELADA"

NUNCA uses el valor de una tabla en otra (ej. "COMPLETADA" en SOLICITUDES es incorrecto,
el valor correcto es "FINALIZADO"). Mezclar estados entre tablas causará error en la DB.

═══════════════════════════════════════════════
CRUCES INTELIGENTES — cuándo usar tablas_relacionadas:
═══════════════════════════════════════════════
• "talleres / sucursales / puntos de atención"                 → tabla_base: SUCURSALES
• "ingresos por sucursal / plata por taller / volumen de pago" → tabla_base: SUCURSALES, tablas_relacionadas: ["PAGOS"]
• "ganancia del taller / cuánto ganó / ingresos / facturación" → tabla_base: PAGOS, col: monto_taller
• "comisión de la app / ganancia de la plataforma"             → tabla_base: PAGOS, col: comision
• "problemas más frecuentes / tipo de servicio / fallas"       → tabla_base: DIAGNOSTICOS (sin cruces), col: categoria_incidencia
• "pagos por tipo de servicio / diagnóstico más rentable"      → tabla_base: DIAGNOSTICOS, tablas_relacionadas: ["PAGOS"]
• "solicitudes con pago / emergencias facturadas"              → tabla_base: PAGOS, tablas_relacionadas: ["SOLICITUDES"]
• "órdenes con pago"                                           → tabla_base: ORDENES, tablas_relacionadas: ["PAGOS"]
• "pujas ganadoras con cobro"                                  → tabla_base: PAGOS, tablas_relacionadas: ["PUJAS"]
• "mecánicos y sus asignaciones"                               → tabla_base: MECANICOS, tablas_relacionadas: ["ASIGNACIONES"]
• Sin cruce implícito                                          → tablas_relacionadas: []

IMPORTANTE: solo cruza entidades que aparezcan en "Puede cruzar con" de tabla_base.
NO inventes cruces que no estén en esa lista.

═══════════════════════════════════════════════
REGLAS PARA COLUMNAS:
═══════════════════════════════════════════════
• Formato obligatorio: "ENTIDAD.alias" — ej: "PAGOS.monto_taller", "DIAGNOSTICOS.nivel_gravedad"
• Si el usuario no especifica columnas concretas → devuelve []

═══════════════════════════════════════════════
RESPUESTA (solo JSON, sin markdown ni texto extra):
═══════════════════════════════════════════════
{{
  "tabla_base":          "NOMBRE_ENTIDAD",
  "tablas_relacionadas": [],
  "columnas":            [],
  "filtros":             {{}},
  "fecha_inicio":        null,
  "fecha_fin":           null,
  "formato":             "{formato_override}"
}}

Restricciones:
• tabla_base: exactamente una de {', '.join(ENTIDADES_PERMITIDAS.keys())}
• tablas_relacionadas: entidades con JOIN válido desde tabla_base (puede ser [])
• filtros: {{"alias_sin_prefijo": "valor"}} — solo columnas de tabla_base
• fecha_inicio / fecha_fin: ISO 8601 (YYYY-MM-DDTHH:MM:SS) o null
• formato: xlsx, csv o pdf

REGLA CRÍTICA DE FORMATO: NUNCA OMITAS las claves "columnas", "tablas_relacionadas"
ni "filtros" en tu respuesta JSON. Si no las necesitas, devuélvelas vacías: [] o {{}}.
Un JSON incompleto causa un error fatal en el sistema. Todas las claves son OBLIGATORIAS.

SOLICITUD DEL USUARIO: "{prompt}"
"""

        try:
            response = model.generate_content(system_prompt)
            raw = response.text.strip()
            if raw.startswith("```"):
                raw = raw.replace("```json", "").replace("```", "").strip()
            resultado: dict = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ValueError(f"La IA no devolvió JSON válido: {exc}") from exc
        except Exception as exc:
            raise ValueError(f"Error al llamar a Gemini: {exc}") from exc

        # ── Validar y sanear (whitelist enforcement — ningún valor de la IA llega al SQL sin pasar por aquí)

        # 1. tabla_base
        tabla_base = str(resultado.get("tabla_base", "")).upper().strip()
        if tabla_base not in ENTIDADES_PERMITIDAS:
            raise ValueError(
                f"La IA devolvió tabla_base inválida: '{tabla_base}'. "
                f"Permitidas: {list(ENTIDADES_PERMITIDAS.keys())}"
            )
        resultado["tabla_base"] = tabla_base
        base_meta = ENTIDADES_PERMITIDAS[tabla_base]
        base_joins = base_meta.get("joins", {})

        # 2. tablas_relacionadas — solo las que tienen JOIN hardcodeado desde tabla_base
        tablas_relacionadas: list[str] = []
        for rel in resultado.get("tablas_relacionadas", []):
            rel_u = str(rel).upper().strip()
            if rel_u in ENTIDADES_PERMITIDAS and rel_u in base_joins:
                tablas_relacionadas.append(rel_u)
            # Silently drop hallucinations — nunca llegan al SQL
        resultado["tablas_relacionadas"] = tablas_relacionadas

        # 3. Columnas — validar contra mapa combinado; normalizar sin prefijo → tabla_base
        all_entities = [tabla_base, *tablas_relacionadas]
        col_map_combined: set[str] = {
            f"{entity}.{alias}"
            for entity in all_entities
            for alias in ENTIDADES_PERMITIDAS[entity]["columnas"]
        }
        valid_cols: list[str] = []
        for col in resultado.get("columnas", []):
            col = str(col).strip()
            if "." in col:
                entity_part, alias_part = col.split(".", 1)
                normalized = f"{entity_part.upper()}.{alias_part}"
                if normalized in col_map_combined:
                    valid_cols.append(normalized)
            else:
                # Sin prefijo → buscar en todas las entidades en orden
                for entity in all_entities:
                    if col in ENTIDADES_PERMITIDAS[entity]["columnas"]:
                        valid_cols.append(f"{entity}.{col}")
                        break
        resultado["columnas"] = valid_cols

        # 4. filtros — solo alias de tabla_base
        base_col_map = base_meta["columnas"]
        resultado["filtros"] = {
            k: v for k, v in resultado.get("filtros", {}).items() if k in base_col_map
        }

        # 5. formato
        fmt = str(resultado.get("formato", formato_override)).lower()
        resultado["formato"] = fmt if fmt in FORMATOS_PERMITIDOS else formato_override

        return resultado

    # ── Generador de Archivos (privado) ───────────────────────────────────────

    def _generar_archivo(
        self, df: pd.DataFrame, formato: str, titulo: str = "Reporte"
    ) -> tuple[io.BytesIO, str]:
        """Convierte un DataFrame a BytesIO en el formato solicitado."""
        buf = io.BytesIO()

        if formato == "csv":
            buf.write(df.to_csv(index=False).encode("utf-8-sig"))
            buf.seek(0)
            return buf, "csv"

        if formato == "xlsx":
            with pd.ExcelWriter(buf, engine="openpyxl") as writer:
                df.to_excel(writer, index=False, sheet_name="Reporte")
            buf.seek(0)
            return buf, "xlsx"

        if formato == "pdf":
            buf = self._generar_pdf(df, titulo)
            return buf, "pdf"

        raise ValueError(f"Formato '{formato}' no soportado.")

    def _generar_pdf(self, df: pd.DataFrame, titulo: str) -> io.BytesIO:
        """Genera un PDF tabular en A4 apaisado con fpdf2."""
        from fpdf import FPDF

        pdf = FPDF(orientation="L", unit="mm", format="A4")
        pdf.set_auto_page_break(auto=True, margin=12)
        pdf.add_page()

        # ── Encabezado ────────────────────────────────────────────────────────
        pdf.set_font("Helvetica", "B", 13)
        pdf.cell(0, 10, titulo, border=0, new_x="LMARGIN", new_y="NEXT", align="C")
        pdf.set_font("Helvetica", "", 8)
        pdf.cell(
            0, 5, f"Generado: {datetime.now().strftime('%d/%m/%Y %H:%M')}",
            border=0, new_x="LMARGIN", new_y="NEXT", align="C",
        )
        pdf.ln(4)

        if df.empty:
            pdf.set_font("Helvetica", "I", 10)
            pdf.cell(0, 10, "Sin datos para el periodo seleccionado.", align="C")
            buf = io.BytesIO(bytes(pdf.output()))
            buf.seek(0)
            return buf

        # ── Dimensiones dinámicas ─────────────────────────────────────────────
        n_cols    = max(len(df.columns), 1)
        col_w     = 270.0 / n_cols   # siempre cabe en A4 apaisado sin overflow
        FONT_SIZE = 8
        MAX_CHARS = 15
        H_HDR     = 7
        H_ROW     = 6

        # Limpiar cabeceras: quitar prefijo de entidad (solicitudes_estado → estado)
        clean_headers = [str(c).split("_", 1)[-1] for c in df.columns]

        # ── Cabecera ──────────────────────────────────────────────────────────
        pdf.set_fill_color(41, 128, 185)
        pdf.set_text_color(255, 255, 255)
        pdf.set_font("Helvetica", "B", FONT_SIZE)
        for header in clean_headers:
            pdf.cell(col_w, H_HDR, header[:MAX_CHARS], border=1, fill=True)
        pdf.ln()

        # ── Filas ─────────────────────────────────────────────────────────────
        pdf.set_text_color(0, 0, 0)
        pdf.set_font("Helvetica", "", FONT_SIZE)
        for idx, (_, row) in enumerate(df.iterrows()):
            fill = (idx % 2 == 0)
            if fill:
                pdf.set_fill_color(240, 245, 250)
            for val in row:
                cell_text = "" if val is None else str(val)[:MAX_CHARS]
                pdf.cell(col_w, H_ROW, cell_text, border=1, fill=fill)
            pdf.ln()

        buf = io.BytesIO(bytes(pdf.output()))
        buf.seek(0)
        return buf
