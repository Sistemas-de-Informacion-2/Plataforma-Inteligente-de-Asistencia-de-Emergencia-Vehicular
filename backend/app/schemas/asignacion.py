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
    motivo_rechazo: str | None = None


# Schemas para el flujo de Asignación/Ejecución 
class AsignarMecanicoRequest(BaseModel):
    """Request body para que el Admin asigne un mecánico a una solicitud."""
    empleado_id: int | None = Field(None, description="ID del empleado (mecánico). Si es None, el admin toma el trabajo.")


class MecanicoRespuestaCreate(BaseModel):
    """Request body para que el mecánico acepte o rechace una asignación."""
    aceptar: bool = Field(..., description="True para aceptar, False para rechazar")
    motivo_rechazo: str | None = Field(
        None, max_length=500,
        description="Motivo del rechazo (requerido si aceptar=False)"
    )


class MecanicoFinalizarCreate(BaseModel):
    """Request body para que el mecánico finalice el trabajo y defina el monto."""
    monto_total: float = Field(..., gt=0, description="El monto final cobrado por el servicio en Bs.")
