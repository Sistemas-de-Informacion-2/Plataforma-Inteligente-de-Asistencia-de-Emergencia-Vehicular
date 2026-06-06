# backend/app/schemas/reportes.py
"""
Contrato de seguridad para el módulo de reportes relacionales.

ENTIDADES_PERMITIDAS es la única fuente de verdad sobre qué tablas, columnas
y JOINs pueden ser consultados dinámicamente.  Ninguna cadena de usuario llega
al SQL sin pasar primero por este diccionario.

Estructura de cada entidad:
  from_clause  — expresión FROM base (puede incluir JOINs internos, ej. MECANICOS→usuarios)
  date_field   — campo usado para filtros de fecha (None si no aplica)
  columnas     — alias_seguro → expresión SQL exacta (nunca viene del usuario)
  base_where   — condición WHERE siempre aplicada
  taller_filter — fragmento WHERE que limita al taller del ADMIN_TALLER (:taller_id bound param)
  joins        — {ENTIDAD_RELACIONADA → "LEFT JOIN ..."}  (hardcodeado, jamás interpolado)
"""
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, field_validator

# ── Formatos de exportación permitidos ────────────────────────────────────────

FORMATOS_PERMITIDOS: frozenset[str] = frozenset({"xlsx", "csv", "pdf"})

# ── Whitelist de entidades, columnas y relaciones ─────────────────────────────

ENTIDADES_PERMITIDAS: dict[str, dict] = {
    "SOLICITUDES": {
        "from_clause": "solicitudes_emergencia",
        "date_field":  "solicitudes_emergencia.fecha_creacion",
        "columnas": {
            "id":                 "solicitudes_emergencia.id",
            "descripcion":        "solicitudes_emergencia.descripcion",
            "estado":             "solicitudes_emergencia.estado",
            "fecha_creacion":     "solicitudes_emergencia.fecha_creacion",
            "fecha_finalizacion": "solicitudes_emergencia.fecha_finalizacion",
            "latitud":            "solicitudes_emergencia.latitud",
            "longitud":           "solicitudes_emergencia.longitud",
            "cliente_id":         "solicitudes_emergencia.cliente_id",
            "vehiculo_id":        "solicitudes_emergencia.vehiculo_id",
        },
        "base_where": "solicitudes_emergencia.es_eliminado = FALSE",
        "taller_filter": (
            "EXISTS ("
            "  SELECT 1 FROM pujas _p"
            "  JOIN sucursales _s ON _s.id = _p.sucursal_id"
            "  WHERE _p.solicitud_id = solicitudes_emergencia.id"
            "    AND _s.taller_id = :taller_id"
            ")"
        ),
        "joins": {
            "DIAGNOSTICOS": (
                "LEFT JOIN diagnosticos_ia"
                " ON diagnosticos_ia.solicitud_id = solicitudes_emergencia.id"
            ),
            "PUJAS": (
                "LEFT JOIN pujas"
                " ON pujas.solicitud_id = solicitudes_emergencia.id"
            ),
            "ASIGNACIONES": (
                "LEFT JOIN asignaciones"
                " ON asignaciones.solicitud_id = solicitudes_emergencia.id"
            ),
            "ORDENES": (
                "LEFT JOIN ordenes_trabajo"
                " ON ordenes_trabajo.solicitud_id = solicitudes_emergencia.id"
            ),
        },
    },
    "MECANICOS": {
        "from_clause": (
            "empleados"
            " JOIN usuarios ON usuarios.id = empleados.usuario_id"
        ),
        "date_field": None,
        "columnas": {
            "id":           "empleados.id",
            "nombre":       "usuarios.nombre",
            "especialidad": "empleados.especialidad",
            "disponible":   "empleados.disponible",
            "sucursal_id":  "empleados.sucursal_id",
        },
        "base_where": "empleados.es_eliminado = FALSE",
        "taller_filter": (
            "empleados.sucursal_id IN ("
            "  SELECT id FROM sucursales WHERE taller_id = :taller_id"
            ")"
        ),
        "joins": {
            "ASIGNACIONES": (
                "LEFT JOIN asignaciones"
                " ON asignaciones.empleado_id = empleados.id"
            ),
            "SOLICITUDES": (
                "LEFT JOIN asignaciones _a ON _a.empleado_id = empleados.id"
                " LEFT JOIN solicitudes_emergencia"
                " ON solicitudes_emergencia.id = _a.solicitud_id"
            ),
            "PAGOS": (
                "LEFT JOIN asignaciones _a_m ON _a_m.empleado_id = empleados.id"
                " LEFT JOIN ordenes_trabajo _o_m"
                " ON _o_m.solicitud_id = _a_m.solicitud_id"
                " LEFT JOIN pagos ON pagos.orden_id = _o_m.id"
                " LEFT JOIN metodos_pago ON metodos_pago.id = pagos.metodo_pago_id"
            ),
        },
    },
    "DIAGNOSTICOS": {
        "from_clause": "diagnosticos_ia",
        "date_field":  "diagnosticos_ia.fecha",
        "columnas": {
            "id":                   "diagnosticos_ia.id",
            "problema_detectado":   "diagnosticos_ia.problema_detectado",
            "nivel_gravedad":       "diagnosticos_ia.nivel_gravedad",
            "costo_estimado_ia":    "diagnosticos_ia.costo_estimado_ia",
            "prioridad":            "diagnosticos_ia.prioridad",
            "categoria_incidencia": "diagnosticos_ia.categoria_incidencia",
            "fecha":                "diagnosticos_ia.fecha",
            "solicitud_id":         "diagnosticos_ia.solicitud_id",
        },
        "base_where": "1=1",
        "taller_filter": (
            "EXISTS ("
            "  SELECT 1 FROM pujas _p"
            "  JOIN sucursales _s ON _s.id = _p.sucursal_id"
            "  WHERE _p.solicitud_id = diagnosticos_ia.solicitud_id"
            "    AND _p.estado = 'ACEPTADA'"
            "    AND _s.taller_id = :taller_id"
            ")"
        ),
        "joins": {
            "SOLICITUDES": (
                "LEFT JOIN solicitudes_emergencia"
                " ON solicitudes_emergencia.id = diagnosticos_ia.solicitud_id"
            ),
            "PUJAS": (
                "LEFT JOIN pujas"
                " ON pujas.solicitud_id = diagnosticos_ia.solicitud_id"
            ),
            "PAGOS": (
                "LEFT JOIN ordenes_trabajo _o_d"
                " ON _o_d.solicitud_id = diagnosticos_ia.solicitud_id"
                " LEFT JOIN pagos ON pagos.orden_id = _o_d.id"
                " LEFT JOIN metodos_pago ON metodos_pago.id = pagos.metodo_pago_id"
            ),
        },
    },
    "ASIGNACIONES": {
        "from_clause": "asignaciones",
        "date_field":  "asignaciones.fecha",
        "columnas": {
            "id":                      "asignaciones.id",
            "estado":                  "asignaciones.estado",
            "fecha":                   "asignaciones.fecha",
            "tiempo_estimado_llegada": "asignaciones.tiempo_estimado_llegada",
            "fecha_aceptacion":        "asignaciones.fecha_aceptacion",
            "fecha_llegada":           "asignaciones.fecha_llegada",
            "solicitud_id":            "asignaciones.solicitud_id",
            "empleado_id":             "asignaciones.empleado_id",
            "sucursal_id":             "asignaciones.sucursal_id",
        },
        "base_where": "1=1",
        "taller_filter": (
            "asignaciones.sucursal_id IN ("
            "  SELECT id FROM sucursales WHERE taller_id = :taller_id"
            ")"
        ),
        "joins": {
            "SOLICITUDES": (
                "LEFT JOIN solicitudes_emergencia"
                " ON solicitudes_emergencia.id = asignaciones.solicitud_id"
            ),
            "MECANICOS": (
                "LEFT JOIN empleados"
                " ON empleados.id = asignaciones.empleado_id"
                " LEFT JOIN usuarios ON usuarios.id = empleados.usuario_id"
            ),
            "PUJAS": (
                "LEFT JOIN pujas"
                " ON pujas.solicitud_id = asignaciones.solicitud_id"
            ),
        },
    },
    "PUJAS": {
        "from_clause": "pujas",
        "date_field":  "pujas.fecha",
        "columnas": {
            "id":                     "pujas.id",
            "precio_estimado":        "pujas.precio_estimado",
            "tiempo_llegada_minutos": "pujas.tiempo_llegada_minutos",
            "estado":                 "pujas.estado",
            "fecha":                  "pujas.fecha",
            "fecha_aceptacion":       "pujas.fecha_aceptacion",
            "solicitud_id":           "pujas.solicitud_id",
            "sucursal_id":            "pujas.sucursal_id",
        },
        "base_where": "1=1",
        "taller_filter": (
            "pujas.sucursal_id IN ("
            "  SELECT id FROM sucursales WHERE taller_id = :taller_id"
            ")"
        ),
        "joins": {
            "SOLICITUDES": (
                "LEFT JOIN solicitudes_emergencia"
                " ON solicitudes_emergencia.id = pujas.solicitud_id"
            ),
            "ASIGNACIONES": (
                "LEFT JOIN asignaciones"
                " ON asignaciones.solicitud_id = pujas.solicitud_id"
            ),
        },
    },
    "ORDENES": {
        "from_clause": "ordenes_trabajo",
        "date_field":  "ordenes_trabajo.fecha_inicio",
        "columnas": {
            "id":           "ordenes_trabajo.id",
            "estado":       "ordenes_trabajo.estado",
            "fecha_inicio": "ordenes_trabajo.fecha_inicio",
            "fecha_fin":    "ordenes_trabajo.fecha_fin",
            "solicitud_id": "ordenes_trabajo.solicitud_id",
            "sucursal_id":  "ordenes_trabajo.sucursal_id",
        },
        "base_where": "ordenes_trabajo.es_eliminado = FALSE",
        "taller_filter": (
            "ordenes_trabajo.sucursal_id IN ("
            "  SELECT id FROM sucursales WHERE taller_id = :taller_id"
            ")"
        ),
        "joins": {
            "SOLICITUDES": (
                "LEFT JOIN solicitudes_emergencia"
                " ON solicitudes_emergencia.id = ordenes_trabajo.solicitud_id"
            ),
            "PAGOS": (
                "LEFT JOIN pagos ON pagos.orden_id = ordenes_trabajo.id"
                " LEFT JOIN metodos_pago ON metodos_pago.id = pagos.metodo_pago_id"
            ),
        },
    },
    "PAGOS": {
        "from_clause": (
            "pagos"
            " LEFT JOIN metodos_pago ON metodos_pago.id = pagos.metodo_pago_id"
        ),
        "date_field":  "pagos.fecha",
        "columnas": {
            "id":           "pagos.id",
            "monto_total":  "pagos.monto_total",
            "comision":     "pagos.comision",
            "monto_taller": "pagos.monto_taller",
            "estado":       "pagos.estado",
            "tipo_pago":    "pagos.tipo_pago",
            "fecha":        "pagos.fecha",
            "metodo_pago":  "metodos_pago.nombre",
            "orden_id":     "pagos.orden_id",
        },
        "base_where": "1=1",
        "taller_filter": (
            "EXISTS ("
            "  SELECT 1 FROM ordenes_trabajo _o"
            "  JOIN sucursales _s ON _s.id = _o.sucursal_id"
            "  WHERE _o.id = pagos.orden_id"
            "    AND _s.taller_id = :taller_id"
            ")"
        ),
        "joins": {
            "ORDENES": (
                "LEFT JOIN ordenes_trabajo"
                " ON ordenes_trabajo.id = pagos.orden_id"
            ),
            "SOLICITUDES": (
                "LEFT JOIN ordenes_trabajo _o ON _o.id = pagos.orden_id"
                " LEFT JOIN solicitudes_emergencia"
                " ON solicitudes_emergencia.id = _o.solicitud_id"
            ),
            "DIAGNOSTICOS": (
                "LEFT JOIN ordenes_trabajo _o_diag ON _o_diag.id = pagos.orden_id"
                " LEFT JOIN diagnosticos_ia"
                " ON diagnosticos_ia.solicitud_id = _o_diag.solicitud_id"
            ),
            "PUJAS": (
                "LEFT JOIN ordenes_trabajo _o_puja ON _o_puja.id = pagos.orden_id"
                " LEFT JOIN pujas"
                " ON pujas.solicitud_id = _o_puja.solicitud_id"
                " AND pujas.estado = 'ACEPTADA'"
            ),
            "MECANICOS": (
                "LEFT JOIN ordenes_trabajo _o_m ON _o_m.id = pagos.orden_id"
                " LEFT JOIN asignaciones _a_m"
                " ON _a_m.solicitud_id = _o_m.solicitud_id"
                " LEFT JOIN empleados ON empleados.id = _a_m.empleado_id"
                " LEFT JOIN usuarios ON usuarios.id = empleados.usuario_id"
            ),
            "SUCURSALES": (
                "LEFT JOIN ordenes_trabajo _o_ps ON _o_ps.id = pagos.orden_id"
                " LEFT JOIN sucursales ON sucursales.id = _o_ps.sucursal_id"
            ),
        },
    },
    "SUCURSALES": {
        "from_clause": (
            "sucursales"
            " LEFT JOIN talleres ON talleres.id = sucursales.taller_id"
        ),
        "date_field":  None,
        "columnas": {
            "id":           "sucursales.id",
            "nombre":       "sucursales.nombre",
            "direccion":    "sucursales.direccion",
            "taller_id":    "sucursales.taller_id",
            "taller_nombre": "talleres.nombre",
        },
        "base_where": "1=1",
        "taller_filter": "sucursales.taller_id = :taller_id",
        "joins": {
            "PAGOS": (
                "LEFT JOIN ordenes_trabajo _o_suc ON _o_suc.sucursal_id = sucursales.id"
                " LEFT JOIN pagos ON pagos.orden_id = _o_suc.id"
                " LEFT JOIN metodos_pago ON metodos_pago.id = pagos.metodo_pago_id"
            ),
        },
    },
}

# ── Schemas Pydantic ───────────────────────────────────────────────────────────


class ReporteManualRequest(BaseModel):
    """
    Parámetros para un reporte dinámico relacional.

    columnas — formato 'ENTIDAD.alias' (ej. 'SOLICITUDES.estado').
               Vacío → se exportan todas las columnas de las entidades seleccionadas.
    filtros  — {alias_sin_prefijo: valor}, aplicados solo sobre tabla_base.
    """
    tabla_base:          str
    tablas_relacionadas: list[str]       = []
    columnas:            list[str]       = []
    filtros:             dict[str, Any]  = {}
    fecha_inicio:        Optional[datetime] = None
    fecha_fin:           Optional[datetime] = None
    formato:             str             = "xlsx"

    @field_validator("tabla_base")
    @classmethod
    def tabla_base_valida(cls, v: str) -> str:
        v = v.upper().strip()
        if v not in ENTIDADES_PERMITIDAS:
            raise ValueError(
                f"Tabla base '{v}' no permitida. "
                f"Opciones: {sorted(ENTIDADES_PERMITIDAS.keys())}"
            )
        return v

    @field_validator("tablas_relacionadas")
    @classmethod
    def relacionadas_validas(cls, v: list[str]) -> list[str]:
        result = []
        for item in v:
            item = item.upper().strip()
            if item not in ENTIDADES_PERMITIDAS:
                raise ValueError(
                    f"Tabla relacionada '{item}' no permitida. "
                    f"Opciones: {sorted(ENTIDADES_PERMITIDAS.keys())}"
                )
            result.append(item)
        return result

    @field_validator("formato")
    @classmethod
    def formato_valido(cls, v: str) -> str:
        v = v.lower().strip()
        if v not in FORMATOS_PERMITIDOS:
            raise ValueError(
                f"Formato '{v}' no soportado. Opciones: {sorted(FORMATOS_PERMITIDOS)}"
            )
        return v


class ReporteIARequest(BaseModel):
    """Parámetros para un reporte generado desde lenguaje natural."""
    prompt:  str
    formato: str = "xlsx"

    @field_validator("formato")
    @classmethod
    def formato_valido(cls, v: str) -> str:
        v = v.lower().strip()
        if v not in FORMATOS_PERMITIDOS:
            raise ValueError(
                f"Formato '{v}' no soportado. Opciones: {sorted(FORMATOS_PERMITIDOS)}"
            )
        return v
