# backend/app/schemas/dashboard.py
"""Schemas de respuesta para los 11 endpoints del Dashboard KPI."""
from typing import Optional
from pydantic import BaseModel


class KPI1TiempoEspera(BaseModel):
    """KPI 1 — Tiempo promedio entre creación del SOS y finalización."""
    minutos_promedio: Optional[float]
    total_finalizadas: int


class KPI2SucursalAceptacion(BaseModel):
    """KPI 2 — Tasa de respuesta de cada sucursal a los SOS recibidos."""
    sucursal_id: int
    nombre: str
    sos_recibidos: int
    sos_respondidos: int
    tasa_aceptacion_pct: Optional[float]


class KPI3TiempoAsignacion(BaseModel):
    """KPI 3 — Tiempo promedio desde SOS creado hasta puja aceptada."""
    minutos_promedio_asignacion: Optional[float]
    total_medidos: int


class KPI4TiempoLlegada(BaseModel):
    """KPI 4 — Tiempo real de llegada vs ETA estimado."""
    minutos_reales_promedio: Optional[float]
    minutos_estimados_promedio: Optional[float]
    delta_promedio_min: Optional[float]
    total_medidos: int


class KPI5IncidenciaItem(BaseModel):
    """KPI 5 — Frecuencia por categoría de falla."""
    categoria_incidencia: Optional[str]
    total: int
    porcentaje: float


class KPI6TallerEficiente(BaseModel):
    """KPI 6 — Score compuesto de eficiencia por sucursal."""
    sucursal_id: int
    nombre: str
    rating_promedio: Optional[float]
    pct_completado: Optional[float]
    delta_puntualidad_min: Optional[float]
    sos_recibidos: int
    tasa_respuesta_pct: Optional[float]


class KPI7MapaCalorItem(BaseModel):
    """KPI 7 — Densidad de incidencias agrupadas por coordenadas."""
    latitud: float
    longitud: float
    densidad: int


class KPI8CanceladosMes(BaseModel):
    """KPI 8 — Tasa de cancelaciones por mes."""
    mes: str
    canceladas: int
    total: int
    tasa_cancelacion_pct: float


class KPI9PuntualidadItem(BaseModel):
    """KPI 9 — Clasificación A_TIEMPO / ATRASADO de asignaciones completadas."""
    cumplimiento: str
    cantidad: int
    porcentaje: float


class KPI10PrecisionCostoItem(BaseModel):
    """KPI 10 — Comparación costo real vs estimación IA vs precio puja."""
    solicitud_id: int
    estimacion_ia: Optional[float]
    precio_puja: Optional[float]
    costo_real: Optional[float]
    delta_vs_ia: Optional[float]
    delta_vs_puja: Optional[float]
    error_pct_ia: Optional[float]


class KPI11MecanicoRankingItem(BaseModel):
    """KPI 11 — Ranking de mecánicos por asignaciones completadas y eficiencia de llegada."""
    empleado_id: int
    nombre: str
    sucursal_nombre: str
    asignaciones_completadas: int
    tiempo_promedio_llegada_min: Optional[float]
    tiempo_promedio_eta_min: Optional[float]
    delta_promedio_min: Optional[float]
