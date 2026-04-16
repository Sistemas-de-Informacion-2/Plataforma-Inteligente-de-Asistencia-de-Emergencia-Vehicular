# backend/app/schemas/orden_trabajo.py
"""
Schemas Pydantic: OrdenTrabajo y DetalleOrden.
"""
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
from app.models.orden_trabajo import EstadoOrden

#  DETALLE ORDEN
class DetalleOrdenBase(BaseModel):
    descripcion: str
    costo: float = Field(..., ge=0)

class DetalleOrdenCreate(DetalleOrdenBase):
    """Se asocia a una orden existente."""
    orden_id: int

class DetalleOrdenOut(DetalleOrdenBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    orden_id: int


#  ORDEN DE TRABAJO
class OrdenTrabajoBase(BaseModel):
    estado: EstadoOrden = EstadoOrden.CREADA

class OrdenTrabajoCreate(OrdenTrabajoBase):
    """Vincular a solicitud y opcionalmente a una sucursal."""
    solicitud_id: int
    sucursal_id: int | None = None

class OrdenTrabajoUpdate(BaseModel):
    estado: EstadoOrden | None = None
    fecha_inicio: datetime | None = None
    fecha_fin: datetime | None = None

class OrdenTrabajoOut(OrdenTrabajoBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    fecha_inicio: datetime | None = None
    fecha_fin: datetime | None = None
    solicitud_id: int
    sucursal_id: int | None = None

class OrdenTrabajoDetallada(OrdenTrabajoOut):
    """Orden con sus detalles y pago embebidos."""
    model_config = ConfigDict(from_attributes=True)
    detalles: list[DetalleOrdenOut] = []
