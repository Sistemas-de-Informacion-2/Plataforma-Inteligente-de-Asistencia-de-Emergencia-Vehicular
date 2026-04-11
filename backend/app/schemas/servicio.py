# backend/app/schemas/servicio.py
"""
Schemas Pydantic: Servicio (Especialidad) y SucursalServicio.
"""

from pydantic import BaseModel, ConfigDict, Field


class ServicioBase(BaseModel):
    nombre: str = Field(..., max_length=150)
    descripcion: str | None = None


class ServicioCreate(ServicioBase):
    pass


class ServicioUpdate(BaseModel):
    nombre: str | None = Field(None, max_length=150)
    descripcion: str | None = None


class ServicioOut(ServicioBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


# ── Vinculación Sucursal ↔ Servicio ──────────────────────────
class SucursalServicioCreate(BaseModel):
    sucursal_id: int
    servicio_id: int


class SucursalServicioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sucursal_id: int
    servicio_id: int
