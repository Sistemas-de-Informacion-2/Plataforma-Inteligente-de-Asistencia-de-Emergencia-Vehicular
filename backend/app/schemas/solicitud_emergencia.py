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
    """Solicitud con evidencias y diagnóstico IA embebidos."""
    model_config = ConfigDict(from_attributes=True)

    evidencias: list["EvidenciaOut"] = []
    diagnostico: "DiagnosticoIAOut | None" = None


# ── Imports diferidos para evitar circular ────────────────────
from app.schemas.evidencia import EvidenciaOut  # noqa: E402
from app.schemas.diagnostico_ia import DiagnosticoIAOut  # noqa: E402

SolicitudDetallada.model_rebuild()
