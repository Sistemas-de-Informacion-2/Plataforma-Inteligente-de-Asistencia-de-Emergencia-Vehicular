"""
Schemas Pydantic: Empleado (Técnico).
"""

from pydantic import BaseModel, ConfigDict, Field


class EmpleadoBase(BaseModel):
    especialidad: str | None = Field(None, max_length=150)
    disponible: bool = True
    latitud: float | None = Field(None, ge=-90, le=90)
    longitud: float | None = Field(None, ge=-180, le=180)


class EmpleadoCreate(EmpleadoBase):
    """Requiere el usuario base y opcionalmente la sucursal."""
    usuario_id: int
    sucursal_id: int | None = None


class EmpleadoUpdate(BaseModel):
    especialidad: str | None = Field(None, max_length=150)
    disponible: bool | None = None
    latitud: float | None = Field(None, ge=-90, le=90)
    longitud: float | None = Field(None, ge=-180, le=180)
    sucursal_id: int | None = None


class EmpleadoOut(EmpleadoBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    usuario_id: int
    sucursal_id: int | None = None
