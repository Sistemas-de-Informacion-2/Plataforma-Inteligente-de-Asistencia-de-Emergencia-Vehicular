# backend/app/schemas/pago.py
"""
Schemas Pydantic: Pago y MetodoPago.
"""

from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
from app.models.pago import EstadoPago

#  MÉTODO DE PAGO
class MetodoPagoBase(BaseModel):
    nombre: str = Field(..., max_length=100)


class MetodoPagoCreate(MetodoPagoBase):
    pass


class MetodoPagoOut(MetodoPagoBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


#  PAGO
class PagoBase(BaseModel):
    monto_total: float = Field(..., gt=0)


class PagoCreate(PagoBase):
    """
    Al crear un pago, la comisión (10%) y el monto_taller (90%)
    se calculan automáticamente en el servicio.
    """
    orden_id: int
    metodo_pago_id: int | None = None


class PagoUpdate(BaseModel):
    estado: EstadoPago | None = None
    metodo_pago_id: int | None = None


class PagoOut(PagoBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    estado: EstadoPago
    fecha: datetime
    comision: float
    monto_taller: float
    orden_id: int
    metodo_pago_id: int | None = None
