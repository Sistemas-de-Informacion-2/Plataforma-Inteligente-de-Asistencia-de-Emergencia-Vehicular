# backend/app/schemas/asignacion.py
"""
Schemas Pydantic: Asignacion.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.asignacion import EstadoAsignacion


class AsignacionBase(BaseModel):
    estado: EstadoAsignacion = EstadoAsignacion.PENDIENTE
    tiempo_estimado_llegada: int | None = Field(
        None, ge=0, description="Minutos estimados de llegada"
    )


class AsignacionCreate(AsignacionBase):
    """Asignar un empleado/sucursal a una solicitud."""
    solicitud_id: int
    empleado_id: int | None = None
    sucursal_id: int | None = None


class AsignacionUpdate(BaseModel):
    estado: EstadoAsignacion | None = None
    tiempo_estimado_llegada: int | None = Field(None, ge=0)


class AsignacionOut(AsignacionBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    fecha: datetime
    solicitud_id: int
    empleado_id: int | None = None
    sucursal_id: int | None = None
