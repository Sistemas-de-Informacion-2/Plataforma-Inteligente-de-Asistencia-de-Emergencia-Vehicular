# backend/app/services/dashboard_service.py
"""
Servicio: DashboardService.
Ejecuta las 10 consultas SQL para los KPIs del dashboard.
Cada método recibe fecha_inicio / fecha_fin opcionales y un taller_id opcional.
  - taller_id = None  →  SUPER_ADMIN, datos globales.
  - taller_id = int   →  ADMIN_TALLER, solo datos de ese taller.
"""
from datetime import datetime
from typing import Optional

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


class DashboardService:

    def __init__(self, session: AsyncSession):
        self.session = session

    # ── Helpers ──────────────────────────────────────────────────────────────

    def _df(self, field: str, fi: Optional[datetime], ff: Optional[datetime]) -> tuple[str, dict]:
        """Fragmento WHERE para filtro de fechas sobre un campo dado."""
        parts: list[str] = []
        params: dict = {}
        if fi:
            parts.append(f"{field} >= :fecha_inicio")
            params["fecha_inicio"] = fi
        if ff:
            parts.append(f"{field} <= :fecha_fin")
            params["fecha_fin"] = ff
        fragment = (" AND " + " AND ".join(parts)) if parts else ""
        return fragment, params

    def _tf_sol(self, sol_col: str, taller_id: Optional[int]) -> tuple[str, dict]:
        """
        Filtra solicitudes por taller usando EXISTS sobre pujas aceptadas.
        sol_col: columna que referencia solicitudes_emergencia.id (ej: 'sol.id').
        """
        if not taller_id:
            return "", {}
        fragment = (
            f" AND EXISTS ("
            f"SELECT 1 FROM pujas _p "
            f"JOIN sucursales _su ON _su.id = _p.sucursal_id "
            f"WHERE _p.solicitud_id = {sol_col} "
            f"AND _su.taller_id = :taller_id)"
        )
        return fragment, {"taller_id": taller_id}

    def _tf_suc(self, suc_alias: str, taller_id: Optional[int]) -> tuple[str, dict]:
        """Filtra sucursales por taller_id directamente."""
        if not taller_id:
            return "", {}
        return f" AND {suc_alias}.taller_id = :taller_id", {"taller_id": taller_id}

    def _tf_asig(self, taller_id: Optional[int]) -> tuple[str, dict]:
        """Filtra asignaciones por sucursal -> taller."""
        if not taller_id:
            return "", {}
        fragment = (
            " AND a.sucursal_id IN "
            "(SELECT id FROM sucursales WHERE taller_id = :taller_id)"
        )
        return fragment, {"taller_id": taller_id}

    def _tf_puja_suc(self, puja_alias: str, taller_id: Optional[int]) -> tuple[str, dict]:
        """Filtra pujas por sucursal -> taller (cuando la puja ya está en FROM)."""
        if not taller_id:
            return "", {}
        fragment = (
            f" AND {puja_alias}.sucursal_id IN "
            "(SELECT id FROM sucursales WHERE taller_id = :taller_id)"
        )
        return fragment, {"taller_id": taller_id}

    async def _q(self, sql: str, params: dict):
        result = await self.session.execute(text(sql), params)
        return result

    # ── KPI 1 — Tiempo de espera total ───────────────────────────────────────

    async def kpi1_tiempo_espera(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> dict:
        df, params = self._df("fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("solicitudes_emergencia.id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT
                ROUND(
                    AVG(EXTRACT(EPOCH FROM (fecha_finalizacion - fecha_creacion)) / 60)::numeric,
                    2
                ) AS minutos_promedio,
                COUNT(*) AS total_finalizadas
            FROM solicitudes_emergencia
            WHERE es_eliminado = FALSE
              AND fecha_finalizacion IS NOT NULL
              {df}{tf}
        """
        row = (await self._q(sql, params)).mappings().one_or_none()
        if not row:
            return {"minutos_promedio": None, "total_finalizadas": 0}
        return {
            "minutos_promedio": float(row["minutos_promedio"]) if row["minutos_promedio"] is not None else None,
            "total_finalizadas": row["total_finalizadas"] or 0,
        }

    # ── KPI 2 — Tasa de aceptación por sucursal ──────────────────────────────

    async def kpi2_tasa_aceptacion(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("n.fecha_envio", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_suc("su", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT
                su.id                                                          AS sucursal_id,
                su.nombre,
                COUNT(n.id)                                                    AS sos_recibidos,
                SUM(CASE WHEN n.respondio THEN 1 ELSE 0 END)                  AS sos_respondidos,
                CASE
                    WHEN COUNT(n.id) > 0
                    THEN ROUND(
                        SUM(CASE WHEN n.respondio THEN 1 ELSE 0 END)::numeric
                        / COUNT(n.id) * 100, 2)
                    ELSE NULL
                END                                                            AS tasa_aceptacion_pct
            FROM sucursales su
            LEFT JOIN sos_notificaciones_sucursal n
                ON n.sucursal_id = su.id {df}
            WHERE su.es_eliminado = FALSE
              {tf}
            GROUP BY su.id, su.nombre
            ORDER BY sos_recibidos DESC, tasa_aceptacion_pct DESC NULLS LAST
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [
            {
                "sucursal_id": r["sucursal_id"],
                "nombre": r["nombre"],
                "sos_recibidos": r["sos_recibidos"] or 0,
                "sos_respondidos": r["sos_respondidos"] or 0,
                "tasa_aceptacion_pct": float(r["tasa_aceptacion_pct"]) if r["tasa_aceptacion_pct"] is not None else None,
            }
            for r in rows
        ]

    # ── KPI 3 — Tiempo promedio de asignación ────────────────────────────────

    async def kpi3_tiempo_asignacion(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> dict:
        df, params = self._df("s.fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_puja_suc("p", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT
                ROUND(
                    AVG(EXTRACT(EPOCH FROM (p.fecha_aceptacion - s.fecha_creacion)) / 60)::numeric,
                    2
                ) AS minutos_promedio_asignacion,
                COUNT(*) AS total_medidos
            FROM pujas p
            JOIN solicitudes_emergencia s ON s.id = p.solicitud_id
            WHERE p.estado = 'ACEPTADA'
              AND p.fecha_aceptacion IS NOT NULL
              AND s.es_eliminado = FALSE
              {df}{tf}
        """
        row = (await self._q(sql, params)).mappings().one_or_none()
        return {
            "minutos_promedio_asignacion": float(row["minutos_promedio_asignacion"]) if row and row["minutos_promedio_asignacion"] is not None else None,
            "total_medidos": (row["total_medidos"] or 0) if row else 0,
        }

    # ── KPI 4 — Tiempo promedio de llegada ───────────────────────────────────

    async def kpi4_tiempo_llegada(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> dict:
        df, params = self._df("a.fecha", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_asig(taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT
                ROUND(
                    AVG(EXTRACT(EPOCH FROM (a.fecha_llegada - a.fecha_aceptacion)) / 60)::numeric,
                    2
                ) AS minutos_reales_promedio,
                ROUND(AVG(a.tiempo_estimado_llegada)::numeric, 2)               AS minutos_estimados_promedio,
                ROUND(
                    (AVG(EXTRACT(EPOCH FROM (a.fecha_llegada - a.fecha_aceptacion)) / 60)
                    - AVG(a.tiempo_estimado_llegada))::numeric,
                    2
                )                                                                AS delta_promedio_min,
                COUNT(*) AS total_medidos
            FROM asignaciones a
            WHERE a.fecha_llegada IS NOT NULL
              AND a.fecha_aceptacion IS NOT NULL
              {df}{tf}
        """
        row = (await self._q(sql, params)).mappings().one_or_none()
        def _f(v):
            return float(v) if v is not None else None
        return {
            "minutos_reales_promedio": _f(row["minutos_reales_promedio"]) if row else None,
            "minutos_estimados_promedio": _f(row["minutos_estimados_promedio"]) if row else None,
            "delta_promedio_min": _f(row["delta_promedio_min"]) if row else None,
            "total_medidos": (row["total_medidos"] or 0) if row else 0,
        }

    # ── KPI 5 — Tipos de incidencia ──────────────────────────────────────────

    async def kpi5_tipos_incidencia(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("d.fecha", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("d.solicitud_id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT
                d.categoria_incidencia,
                COUNT(*)                                                      AS total,
                ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::numeric, 2)  AS porcentaje
            FROM diagnosticos_ia d
            WHERE d.categoria_incidencia IS NOT NULL
              {df}{tf}
            GROUP BY d.categoria_incidencia
            ORDER BY total DESC
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [
            {
                "categoria_incidencia": r["categoria_incidencia"],
                "total": r["total"],
                "porcentaje": float(r["porcentaje"]),
            }
            for r in rows
        ]

    # ── KPI 6 — Ranking de talleres más eficientes ───────────────────────────

    async def kpi6_ranking_talleres(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df_asig, params = self._df("fecha", fecha_inicio, fecha_fin)
        df_notif, params_notif = self._df("fecha_envio", fecha_inicio, fecha_fin)
        df_resena, params_resena = self._df("fecha", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_suc("su", taller_id)
        params = {**params, **tparams}

        sql = f"""
            SELECT
                su.id                                              AS sucursal_id,
                su.nombre,
                ratings.rating_promedio,
                ops.pct_completado,
                ops.delta_puntualidad_min,
                COALESCE(notifs.sos_recibidos, 0)                 AS sos_recibidos,
                notifs.tasa_respuesta_pct
            FROM sucursales su
            LEFT JOIN (
                SELECT
                    sucursal_id,
                    ROUND(AVG(puntuacion)::numeric, 2) AS rating_promedio
                FROM resenas_foro
                WHERE 1=1 {df_resena}
                GROUP BY sucursal_id
            ) ratings ON ratings.sucursal_id = su.id
            LEFT JOIN (
                SELECT
                    sucursal_id,
                    ROUND(
                        COUNT(CASE WHEN estado = 'COMPLETADA' THEN 1 END)::numeric
                        / NULLIF(COUNT(*), 0) * 100, 2
                    )                                              AS pct_completado,
                    ROUND(
                        (AVG(EXTRACT(EPOCH FROM (fecha_llegada - fecha_aceptacion)) / 60)
                        - AVG(tiempo_estimado_llegada))::numeric, 2
                    )                                              AS delta_puntualidad_min
                FROM asignaciones
                WHERE 1=1 {df_asig}
                GROUP BY sucursal_id
            ) ops ON ops.sucursal_id = su.id
            LEFT JOIN (
                SELECT
                    sucursal_id,
                    COUNT(*)                                       AS sos_recibidos,
                    ROUND(
                        SUM(CASE WHEN respondio THEN 1 ELSE 0 END)::numeric
                        / NULLIF(COUNT(*), 0) * 100, 2
                    )                                              AS tasa_respuesta_pct
                FROM sos_notificaciones_sucursal
                WHERE 1=1 {df_notif}
                GROUP BY sucursal_id
            ) notifs ON notifs.sucursal_id = su.id
            WHERE su.es_eliminado = FALSE
              {tf}
            ORDER BY
                COALESCE(ratings.rating_promedio, 0) DESC,
                COALESCE(ops.pct_completado, 0)      DESC
        """
        rows = (await self._q(sql, params)).mappings().all()
        def _f(v):
            return float(v) if v is not None else None
        return [
            {
                "sucursal_id": r["sucursal_id"],
                "nombre": r["nombre"],
                "rating_promedio": _f(r["rating_promedio"]),
                "pct_completado": _f(r["pct_completado"]),
                "delta_puntualidad_min": _f(r["delta_puntualidad_min"]),
                "sos_recibidos": r["sos_recibidos"] or 0,
                "tasa_respuesta_pct": _f(r["tasa_respuesta_pct"]),
            }
            for r in rows
        ]

    # ── KPI 7 — Mapa de calor ────────────────────────────────────────────────

    async def kpi7_mapa_calor(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("solicitudes_emergencia.id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT
                ROUND(latitud::numeric, 3)  AS latitud,
                ROUND(longitud::numeric, 3) AS longitud,
                COUNT(*)                    AS densidad
            FROM solicitudes_emergencia
            WHERE es_eliminado = FALSE
              {df}{tf}
            GROUP BY ROUND(latitud::numeric, 3), ROUND(longitud::numeric, 3)
            ORDER BY densidad DESC
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [
            {
                "latitud": float(r["latitud"]),
                "longitud": float(r["longitud"]),
                "densidad": r["densidad"],
            }
            for r in rows
        ]

    # ── KPI 8 — Tasa de cancelados por mes ───────────────────────────────────

    async def kpi8_tasa_cancelados(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("solicitudes_emergencia.id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT
                TO_CHAR(DATE_TRUNC('month', fecha_creacion), 'YYYY-MM')   AS mes,
                COUNT(*) FILTER (WHERE estado = 'CANCELADO')              AS canceladas,
                COUNT(*)                                                   AS total,
                ROUND(
                    COUNT(*) FILTER (WHERE estado = 'CANCELADO')::numeric
                    / COUNT(*) * 100, 2
                )                                                          AS tasa_cancelacion_pct
            FROM solicitudes_emergencia
            WHERE es_eliminado = FALSE
              {df}{tf}
            GROUP BY DATE_TRUNC('month', fecha_creacion)
            ORDER BY DATE_TRUNC('month', fecha_creacion) DESC
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [
            {
                "mes": r["mes"],
                "canceladas": r["canceladas"] or 0,
                "total": r["total"],
                "tasa_cancelacion_pct": float(r["tasa_cancelacion_pct"]),
            }
            for r in rows
        ]

    # ── KPI 9 — Puntualidad (a tiempo vs atrasado) ───────────────────────────

    async def kpi9_puntualidad(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("a.fecha", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_asig(taller_id)
        params = {**params, **tparams}
        sql = f"""
            WITH clasificados AS (
                SELECT
                    CASE
                        WHEN EXTRACT(EPOCH FROM (a.fecha_llegada - a.fecha_aceptacion)) / 60
                             <= a.tiempo_estimado_llegada
                        THEN 'A_TIEMPO'
                        ELSE 'ATRASADO'
                    END AS cumplimiento
                FROM asignaciones a
                WHERE a.fecha_llegada IS NOT NULL
                  AND a.fecha_aceptacion IS NOT NULL
                  AND a.tiempo_estimado_llegada IS NOT NULL
                  {df}{tf}
            )
            SELECT
                cumplimiento,
                COUNT(*)                                                     AS cantidad,
                ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::numeric, 2) AS porcentaje
            FROM clasificados
            GROUP BY cumplimiento
            ORDER BY cumplimiento
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [
            {
                "cumplimiento": r["cumplimiento"],
                "cantidad": r["cantidad"],
                "porcentaje": float(r["porcentaje"]),
            }
            for r in rows
        ]

    # ── KPI 11 — Ranking de mecánicos (solo ADMIN_TALLER) ───────────────────

    async def kpi11_ranking_mecanicos(
        self,
        taller_id: int,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
    ) -> list[dict]:
        # El filtro de fecha va en el ON del LEFT JOIN para no excluir mecánicos sin asignaciones en el rango
        df, params = self._df("a.fecha", fecha_inicio, fecha_fin)
        params["taller_id"] = taller_id
        sql = f"""
            SELECT
                e.id                                                                        AS empleado_id,
                u.nombre,
                su.nombre                                                                   AS sucursal_nombre,
                COUNT(a.id) FILTER (WHERE a.estado = 'COMPLETADA')                         AS asignaciones_completadas,
                ROUND(
                    (AVG(EXTRACT(EPOCH FROM (a.fecha_llegada - a.fecha_aceptacion)) / 60)
                     FILTER (WHERE a.fecha_llegada IS NOT NULL AND a.fecha_aceptacion IS NOT NULL)
                    )::numeric,
                    2
                )                                                                           AS tiempo_promedio_llegada_min,
                ROUND(
                    (AVG(a.tiempo_estimado_llegada)
                     FILTER (WHERE a.tiempo_estimado_llegada IS NOT NULL))::numeric,
                    2
                )                                                                           AS tiempo_promedio_eta_min,
                ROUND(
                    ((AVG(EXTRACT(EPOCH FROM (a.fecha_llegada - a.fecha_aceptacion)) / 60)
                      FILTER (WHERE a.fecha_llegada IS NOT NULL AND a.fecha_aceptacion IS NOT NULL))
                    - (AVG(a.tiempo_estimado_llegada)
                       FILTER (WHERE a.tiempo_estimado_llegada IS NOT NULL)))::numeric,
                    2
                )                                                                           AS delta_promedio_min
            FROM empleados e
            JOIN usuarios u    ON u.id  = e.usuario_id
            JOIN sucursales su ON su.id = e.sucursal_id
            LEFT JOIN asignaciones a ON a.empleado_id = e.id {df}
            WHERE su.taller_id = :taller_id
            GROUP BY e.id, u.nombre, su.id, su.nombre
            ORDER BY asignaciones_completadas DESC, delta_promedio_min ASC NULLS LAST
        """
        rows = (await self._q(sql, params)).mappings().all()
        def _f(v):
            return float(v) if v is not None else None
        return [
            {
                "empleado_id": r["empleado_id"],
                "nombre": r["nombre"],
                "sucursal_nombre": r["sucursal_nombre"],
                "asignaciones_completadas": r["asignaciones_completadas"] or 0,
                "tiempo_promedio_llegada_min": _f(r["tiempo_promedio_llegada_min"]),
                "tiempo_promedio_eta_min": _f(r["tiempo_promedio_eta_min"]),
                "delta_promedio_min": _f(r["delta_promedio_min"]),
            }
            for r in rows
        ]

    # ── KPI 10 — Precisión de estimación de costos ───────────────────────────

    async def kpi10_precision_costos(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("sol.fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_puja_suc("puja", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT
                sol.id                                                          AS solicitud_id,
                diag.costo_estimado_ia                                          AS estimacion_ia,
                puja.precio_estimado                                            AS precio_puja,
                SUM(det.costo)                                                  AS costo_real,
                ROUND((SUM(det.costo) - diag.costo_estimado_ia)::numeric, 2)   AS delta_vs_ia,
                ROUND((SUM(det.costo) - puja.precio_estimado)::numeric, 2)     AS delta_vs_puja,
                ROUND(
                    (ABS(SUM(det.costo) - diag.costo_estimado_ia)
                    / NULLIF(diag.costo_estimado_ia, 0) * 100)::numeric
                , 2)                                                            AS error_pct_ia
            FROM solicitudes_emergencia sol
            JOIN diagnosticos_ia diag  ON diag.solicitud_id  = sol.id
            JOIN pujas puja            ON puja.solicitud_id  = sol.id
                                     AND puja.estado         = 'ACEPTADA'
            JOIN ordenes_trabajo ord   ON ord.solicitud_id   = sol.id
            JOIN detalles_orden det    ON det.orden_id       = ord.id
            WHERE sol.es_eliminado = FALSE
              {df}{tf}
            GROUP BY sol.id, diag.costo_estimado_ia, puja.precio_estimado
            ORDER BY ABS(SUM(det.costo) - diag.costo_estimado_ia) DESC NULLS LAST
        """
        rows = (await self._q(sql, params)).mappings().all()
        def _f(v):
            return float(v) if v is not None else None
        return [
            {
                "solicitud_id": r["solicitud_id"],
                "estimacion_ia": _f(r["estimacion_ia"]),
                "precio_puja": _f(r["precio_puja"]),
                "costo_real": _f(r["costo_real"]),
                "delta_vs_ia": _f(r["delta_vs_ia"]),
                "delta_vs_puja": _f(r["delta_vs_puja"]),
                "error_pct_ia": _f(r["error_pct_ia"]),
            }
            for r in rows
        ]

    # ── KPI 12 — Liquidez del Marketplace ─────────────────────────────────────

    async def kpi12_liquidez_marketplace(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> dict:
        df, params = self._df("sol.fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("sol.id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT 
                ROUND(AVG(p.cant_pujas)::numeric, 2) AS promedio_pujas,
                COUNT(sol.id) AS total_solicitudes
            FROM solicitudes_emergencia sol
            LEFT JOIN LATERAL (
                SELECT COUNT(*) as cant_pujas 
                FROM pujas 
                WHERE solicitud_id = sol.id
            ) p ON true
            WHERE sol.es_eliminado = FALSE
              {df}{tf}
        """
        row = (await self._q(sql, params)).mappings().one_or_none()
        return {
            "promedio_pujas": float(row["promedio_pujas"]) if row and row["promedio_pujas"] is not None else 0.0,
            "total_solicitudes": row["total_solicitudes"] if row else 0
        }

    # ── KPI 13 — Ingresos por Comisiones ──────────────────────────────────────

    async def kpi13_ingresos_comisiones(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("pago.fecha", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_puja_suc("puja", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT 
                TO_CHAR(DATE_TRUNC('month', pago.fecha), 'YYYY-MM') AS mes,
                SUM(pago.comision) AS total_comision
            FROM pagos pago
            JOIN ordenes_trabajo ord ON ord.id = pago.orden_id
            JOIN pujas puja ON puja.solicitud_id = ord.solicitud_id AND puja.estado = 'ACEPTADA'
            WHERE pago.estado = 'COMPLETADO'
              {df}{tf}
            GROUP BY DATE_TRUNC('month', pago.fecha)
            ORDER BY DATE_TRUNC('month', pago.fecha) DESC
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [{"mes": r["mes"], "total_comision": float(r["total_comision"]) if r["total_comision"] else 0.0} for r in rows]

    # ── KPI 14 — Horas y Días Pico ────────────────────────────────────────────

    async def kpi14_horas_pico(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT 
                CAST(EXTRACT(DOW FROM fecha_creacion) AS INTEGER) AS dia_semana,
                CAST(EXTRACT(HOUR FROM fecha_creacion) AS INTEGER) AS hora,
                COUNT(*) AS cantidad
            FROM solicitudes_emergencia
            WHERE es_eliminado = FALSE
              {df}{tf}
            GROUP BY EXTRACT(DOW FROM fecha_creacion), EXTRACT(HOUR FROM fecha_creacion)
            ORDER BY dia_semana, hora
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [{"dia_semana": r["dia_semana"], "hora": r["hora"], "cantidad": r["cantidad"]} for r in rows]

    # ── KPI 15 — Retención de Clientes ────────────────────────────────────────

    async def kpi15_retencion_clientes(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            WITH conteo AS (
                SELECT cliente_id, COUNT(*) as usos
                FROM solicitudes_emergencia
                WHERE es_eliminado = FALSE {df}{tf}
                GROUP BY cliente_id
            ),
            agrupado AS (
                SELECT 
                    CASE WHEN usos = 1 THEN 'Un solo uso' ELSE 'Recurrente' END AS tipo,
                    COUNT(*) AS cantidad
                FROM conteo
                GROUP BY CASE WHEN usos = 1 THEN 'Un solo uso' ELSE 'Recurrente' END
            )
            SELECT 
                tipo, 
                cantidad, 
                ROUND(cantidad * 100.0 / NULLIF(SUM(cantidad) OVER (), 0)::numeric, 2) AS porcentaje
            FROM agrupado
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [{"tipo": r["tipo"], "cantidad": r["cantidad"], "porcentaje": float(r["porcentaje"] or 0.0)} for r in rows]

    # ── KPI 16 — Embudo de Abandono ───────────────────────────────────────────

    async def kpi16_embudo_abandono(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("sol.fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("sol.id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT 
                '1. Creadas' AS etapa, COUNT(*) AS cantidad
            FROM solicitudes_emergencia sol WHERE es_eliminado = FALSE {df}{tf}
            UNION ALL
            SELECT 
                '2. Con Pujas' AS etapa, COUNT(DISTINCT sol.id) AS cantidad
            FROM solicitudes_emergencia sol
            JOIN pujas p ON p.solicitud_id = sol.id
            WHERE sol.es_eliminado = FALSE {df}{tf}
            UNION ALL
            SELECT 
                '3. Asignadas' AS etapa, COUNT(DISTINCT sol.id) AS cantidad
            FROM solicitudes_emergencia sol
            JOIN pujas p ON p.solicitud_id = sol.id AND p.estado = 'ACEPTADA'
            WHERE sol.es_eliminado = FALSE {df}{tf}
            UNION ALL
            SELECT 
                '4. Completadas' AS etapa, COUNT(DISTINCT sol.id) AS cantidad
            FROM solicitudes_emergencia sol
            JOIN asignaciones a ON a.solicitud_id = sol.id AND a.estado = 'COMPLETADA'
            WHERE sol.es_eliminado = FALSE {df}{tf}
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [{"etapa": r["etapa"], "cantidad": r["cantidad"]} for r in rows]

    # ── KPI 17 — Win Rate de Pujas ────────────────────────────────────────────

    async def kpi17_win_rate_pujas(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("p.fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_puja_suc("p", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT 
                CASE WHEN p.estado = 'ACEPTADA' THEN 'Aceptada' ELSE 'Rechazada/Ignorada' END AS estado,
                COUNT(*) AS cantidad,
                ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0)::numeric, 2) AS porcentaje
            FROM pujas p
            WHERE 1=1 {df}{tf}
            GROUP BY CASE WHEN p.estado = 'ACEPTADA' THEN 'Aceptada' ELSE 'Rechazada/Ignorada' END
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [{"estado": r["estado"], "cantidad": r["cantidad"], "porcentaje": float(r["porcentaje"] or 0.0)} for r in rows]

    # ── KPI 18 — Evolución de Ingresos y Ticket Promedio ──────────────────────

    async def kpi18_evolucion_ingresos(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("pago.fecha", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_puja_suc("puja", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT 
                TO_CHAR(DATE_TRUNC('month', pago.fecha), 'YYYY-MM') AS mes,
                SUM(pago.monto_taller) AS ingresos_netos,
                ROUND(AVG(pago.monto_total)::numeric, 2) AS ticket_promedio
            FROM pagos pago
            JOIN ordenes_trabajo ord ON ord.id = pago.orden_id
            JOIN pujas puja ON puja.solicitud_id = ord.solicitud_id AND puja.estado = 'ACEPTADA'
            WHERE pago.estado = 'COMPLETADO'
              {df}{tf}
            GROUP BY DATE_TRUNC('month', pago.fecha)
            ORDER BY DATE_TRUNC('month', pago.fecha) DESC
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [{
            "mes": r["mes"], 
            "ingresos_netos": float(r["ingresos_netos"]) if r["ingresos_netos"] else 0.0,
            "ticket_promedio": float(r["ticket_promedio"]) if r["ticket_promedio"] else 0.0
        } for r in rows]

    # ── KPI 19 — Top Vehículos ────────────────────────────────────────────────

    async def kpi19_top_vehiculos(
        self,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime],
        taller_id: Optional[int] = None,
    ) -> list[dict]:
        df, params = self._df("sol.fecha_creacion", fecha_inicio, fecha_fin)
        tf, tparams = self._tf_sol("sol.id", taller_id)
        params = {**params, **tparams}
        sql = f"""
            SELECT 
                COALESCE(v.marca, 'Desconocida') AS marca,
                COALESCE(v.modelo, 'Desconocido') AS modelo,
                COUNT(*) AS cantidad
            FROM solicitudes_emergencia sol
            LEFT JOIN vehiculos v ON v.id = sol.vehiculo_id
            WHERE sol.es_eliminado = FALSE
              {df}{tf}
            GROUP BY v.marca, v.modelo
            ORDER BY cantidad DESC
            LIMIT 10
        """
        rows = (await self._q(sql, params)).mappings().all()
        return [{"marca": r["marca"], "modelo": r["modelo"], "cantidad": r["cantidad"]} for r in rows]

    # ── KPI 20 — Tiempos Operativos de Mecánicos ──────────────────────────────

    async def kpi20_tiempos_operativos_mecanico(
        self,
        taller_id: int,
        fecha_inicio: Optional[datetime],
        fecha_fin: Optional[datetime]
    ) -> list[dict]:
        df, params = self._df("a.fecha", fecha_inicio, fecha_fin)
        params["taller_id"] = taller_id
        sql = f"""
            SELECT 
                e.id AS empleado_id,
                u.nombre AS nombre,
                ROUND(AVG(EXTRACT(EPOCH FROM (a.fecha_llegada - a.fecha_aceptacion)) / 60)::numeric, 2) AS tiempo_ruta_min,
                ROUND(AVG(EXTRACT(EPOCH FROM (sol.fecha_finalizacion - a.fecha_llegada)) / 60)::numeric, 2) AS tiempo_sitio_min
            FROM empleados e
            JOIN usuarios u ON u.id = e.usuario_id
            JOIN sucursales su ON su.id = e.sucursal_id
            JOIN asignaciones a ON a.empleado_id = e.id AND a.estado = 'COMPLETADA'
            JOIN solicitudes_emergencia sol ON sol.id = a.solicitud_id AND sol.fecha_finalizacion IS NOT NULL
            WHERE su.taller_id = :taller_id {df}
            GROUP BY e.id, u.nombre
            ORDER BY (COALESCE(AVG(EXTRACT(EPOCH FROM (a.fecha_llegada - a.fecha_aceptacion)) / 60), 0) + 
                      COALESCE(AVG(EXTRACT(EPOCH FROM (sol.fecha_finalizacion - a.fecha_llegada)) / 60), 0)) DESC
        """
        rows = (await self._q(sql, params)).mappings().all()
        def _f(v): return float(v) if v is not None else None
        return [{
            "empleado_id": r["empleado_id"],
            "nombre": r["nombre"],
            "tiempo_ruta_min": _f(r["tiempo_ruta_min"]),
            "tiempo_sitio_min": _f(r["tiempo_sitio_min"])
        } for r in rows]
