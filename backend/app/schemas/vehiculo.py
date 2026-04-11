# backend/app/schemas/vehiculo.py
"""
Schemas Pydantic: Vehiculo.
"""
from pydantic import BaseModel, ConfigDict, Field


class VehiculoBase(BaseModel):
    marca: str = Field(..., max_length=100)
    modelo: str = Field(..., max_length=100)
    anio: int = Field(..., ge=1900, le=2100)
    placa: str = Field(..., max_length=20)


class VehiculoCreate(VehiculoBase):
    """Requiere el ID del propietario."""
    usuario_id: int


class VehiculoUpdate(BaseModel):
    """Campos opcionales para actualizar un vehículo."""
    marca: str | None = Field(None, max_length=100)
    modelo: str | None = Field(None, max_length=100)
    anio: int | None = Field(None, ge=1900, le=2100)
    placa: str | None = Field(None, max_length=20)


class VehiculoOut(VehiculoBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    usuario_id: int
