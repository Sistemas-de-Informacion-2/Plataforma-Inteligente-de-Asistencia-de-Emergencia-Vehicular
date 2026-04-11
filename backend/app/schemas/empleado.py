# backend/app/schemas/empleado.py
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


class EmpleadoCreateFull(BaseModel):
    """
    Schema para crear Usuario + Empleado en una sola transacción.
    Usado por el Admin cuando registra un nuevo técnico.
    """
    # Datos del usuario base
    nombre: str = Field(..., min_length=1, max_length=100)
    email: str = Field(..., max_length=150)
    password: str = Field(..., min_length=6, max_length=255)
    ci: str = Field(..., min_length=1, max_length=20)
    telefono: str | None = Field(None, max_length=20)

    # Datos del empleado
    especialidad: str | None = Field(None, max_length=150)
    sucursal_id: int
    latitud: float | None = Field(None, ge=-90, le=90)
    longitud: float | None = Field(None, ge=-180, le=180)


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


class EmpleadoConUsuario(EmpleadoOut):
    """Empleado con datos básicos del usuario que extiende."""
    model_config = ConfigDict(from_attributes=True)

    nombre_usuario: str | None = None
    email_usuario: str | None = None
