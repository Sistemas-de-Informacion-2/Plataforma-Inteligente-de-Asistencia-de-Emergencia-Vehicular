# backend/app/schemas/rol.py
"""
Schemas Pydantic: Rol y Permiso.
"""
from pydantic import BaseModel, ConfigDict, Field

#  PERMISO
class PermisoBase(BaseModel):
    nombre: str = Field(..., max_length=100)
    descripcion: str | None = Field(None, max_length=255)

class PermisoCreate(PermisoBase):
    pass

class PermisoOut(PermisoBase):
    model_config = ConfigDict(from_attributes=True)
    id: int


#  ROL
class RolBase(BaseModel):
    nombre: str = Field(..., max_length=50)

class RolCreate(RolBase):
    permisos_ids: list[int] = []

class RolUpdate(BaseModel):
    nombre: str | None = Field(None, max_length=50)
    permisos_ids: list[int] | None = None

class RolOut(RolBase):
    model_config = ConfigDict(from_attributes=True)
    id: int

class RolConPermisos(RolOut):
    """Rol con sus permisos cargados."""
    model_config = ConfigDict(from_attributes=True)

    permisos: list[PermisoOut] = []


#  Asignación de Rol a Usuario
class UsuarioRolCreate(BaseModel):
    usuario_id: int
    rol_id: int


class UsuarioRolOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    usuario_id: int
    rol_id: int
