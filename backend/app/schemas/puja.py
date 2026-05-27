# backend/app/schemas/puja.py
"""
Schemas Pydantic: Puja (Marketplace inDrive).
"""
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
from app.models.puja import EstadoPuja


class PujaCreate(BaseModel):
    """
    Payload que envía el taller al pujar.
    Solo necesita el precio — el backend calcula el ETA con PostGIS.
    """
    solicitud_id: int
    precio_estimado: float = Field(..., gt=0, description="Precio ofertado en BOB")


class PujaOut(BaseModel):
    """Puja completa serializada (para respuestas HTTP)."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    solicitud_id: int
    sucursal_id: int
    precio_estimado: float
    tiempo_llegada_minutos: int
    estado: EstadoPuja
    fecha: datetime

    # Datos enriquecidos de la sucursal (se llenan en el service)
    sucursal_nombre: str = ""
    taller_nombre: str = ""
    rating: float = 0.0
    rating_count: int = 0
    distancia_km: float = 0.0


class PujaWebSocketPayload(BaseModel):
    """
    Payload optimizado para el evento NUEVA_PUJA_RECIBIDA.
    Se envía al cliente vía WebSocket cada vez que un taller puja.
    """
    type: str = "NUEVA_PUJA_RECIBIDA"
    puja_id: int
    solicitud_id: int
    sucursal_id: int
    sucursal_nombre: str
    taller_nombre: str
    precio_estimado: float
    tiempo_llegada_minutos: int
    rating: float = 0.0
    rating_count: int = 0
    distancia_km: float = 0.0
    fecha: str  # ISO 8601


class PujaSeleccion(BaseModel):
    """Payload para que el cliente seleccione la puja ganadora."""
    puja_id: int
