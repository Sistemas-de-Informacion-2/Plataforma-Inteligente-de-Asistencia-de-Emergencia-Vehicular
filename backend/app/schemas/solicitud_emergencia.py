# backend/app/schemas/solicitud_emergencia.py
"""
Schemas Pydantic: SolicitudEmergencia.
"""
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
from app.models.solicitud_emergencia import EstadoSolicitud

class SolicitudBase(BaseModel):
    descripcion: str | None = None
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)

class SolicitudCreate(SolicitudBase):
    """Crear una solicitud de emergencia. El estado inicia como PENDIENTE."""
    cliente_id: int
    vehiculo_id: int | None = None

class SolicitudUpdate(BaseModel):
    """Actualización parcial de la solicitud."""
    descripcion: str | None = None
    estado: EstadoSolicitud | None = None

class SolicitudOut(SolicitudBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    estado: EstadoSolicitud
    fecha_creacion: datetime
    cliente_id: int
    vehiculo_id: int | None = None

class SolicitudDetallada(SolicitudOut):
    """Solicitud con evidencias, diagnóstico IA y vehículo embebidos."""
    model_config = ConfigDict(from_attributes=True)
    evidencias: list["EvidenciaOut"] = []
    diagnostico: "DiagnosticoIAOut | None" = None
    vehiculo: "VehiculoOut | None" = None
    asignaciones: list["AsignacionOut"] = []


# ── Schemas de recomendación (Fase 1: Uber para Mecánicos Inverso) ──
class SucursalRecomendada(BaseModel):
    """Sucursal candidata con metadata de ranking para la UI del cliente."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    direccion: str | None = None
    telefono: str | None = None
    latitud: float
    longitud: float
    taller_id: int
    taller_nombre: str
    distancia_km: float
    tiene_servicio: bool
    rating: float = 0.0
    rating_count: int = 0
    tecnicos_disponibles: int
    score: float
    eta_minutos: int


class SolicitudSeleccionTaller(BaseModel):
    """Payload para que el cliente elija un taller de las recomendaciones."""
    sucursal_id: int


class SolicitudRecomendacionOut(BaseModel):
    """
    Respuesta del flujo de emergencia Fase 1.
    Contiene la solicitud creada, el diagnóstico de IA,
    y la lista de sucursales recomendadas para que el cliente elija.
    """
    solicitud: SolicitudOut
    diagnostico_ia: "DiagnosticoIAOut"
    sucursales_recomendadas: list[SucursalRecomendada] = []


class SolicitudSOSOut(BaseModel):
    """
    Respuesta del flujo SOS inDrive (Marketplace de Pujas).
    Solo contiene la solicitud + diagnóstico IA.
    Las pujas llegarán en tiempo real vía WebSocket (NUEVA_PUJA_RECIBIDA).
    """
    solicitud: SolicitudOut
    diagnostico_ia: "DiagnosticoIAOut"
    mensaje: str = "SOS emitido. Esperando pujas de talleres cercanos en tiempo real."
    talleres_notificados: int = 0


# ── Imports diferidos para evitar circular ────────────────────
from app.schemas.evidencia import EvidenciaOut  # noqa: E402
from app.schemas.diagnostico_ia import DiagnosticoIAOut  # noqa: E402
from app.schemas.vehiculo import VehiculoOut  # noqa: E402
from app.schemas.asignacion import AsignacionOut  # noqa: E402

SolicitudDetallada.model_rebuild()
SolicitudRecomendacionOut.model_rebuild()
SolicitudSOSOut.model_rebuild()
