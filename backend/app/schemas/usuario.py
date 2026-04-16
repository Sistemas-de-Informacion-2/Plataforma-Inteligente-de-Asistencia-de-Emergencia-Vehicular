# backend/app/schemas/usuario.py
"""
Schemas Pydantic: Usuario y UsuarioPerfil.
"""
from datetime import datetime, date
from pydantic import BaseModel, ConfigDict, EmailStr, Field

#  USUARIO PERFIL
class UsuarioPerfilBase(BaseModel):
    segundo_nombre: str | None = None
    apellido_paterno: str
    apellido_materno: str | None = None
    foto_perfil: str | None = None
    fecha_nacimiento: date | None = None

class UsuarioPerfilCreate(UsuarioPerfilBase):
    pass

class UsuarioPerfilUpdate(BaseModel):
    segundo_nombre: str | None = None
    apellido_paterno: str | None = None
    apellido_materno: str | None = None
    foto_perfil: str | None = None
    fecha_nacimiento: date | None = None

class UsuarioPerfilOut(UsuarioPerfilBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    usuario_id: int

class UsuarioPerfilCompletoUpdate(BaseModel):
    """Actualiza campos editables del Perfil del usuario (Usuario y UsuarioPerfil)"""
    nombre: str | None = Field(None, max_length=100)
    telefono: str | None = Field(None, max_length=20)
    segundo_nombre: str | None = None
    apellido_paterno: str | None = None
    apellido_materno: str | None = None
    foto_perfil: str | None = None
    fecha_nacimiento: date | None = None


#  USUARIO
class UsuarioBase(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=100)
    email: str = Field(..., max_length=150)
    telefono: str | None = Field(None, max_length=20)
    ci: str = Field(..., min_length=1, max_length=20)

class UsuarioCreate(UsuarioBase):
    """Datos necesarios para registrar un usuario."""
    password: str = Field(..., min_length=6, max_length=255)
    perfil: UsuarioPerfilCreate | None = None

class UsuarioUpdate(BaseModel):
    """Campos opcionales para actualizar un usuario."""
    nombre: str | None = Field(None, max_length=100)
    email: str | None = Field(None, max_length=150)
    telefono: str | None = Field(None, max_length=20)
    ci: str | None = Field(None, max_length=20)

class UsuarioOut(UsuarioBase):
    """Datos públicos del usuario (sin password)."""
    model_config = ConfigDict(from_attributes=True)
    id: int
    fecha_creacion: datetime
    perfil: UsuarioPerfilOut | None = None


class UsuarioConRoles(UsuarioOut):
    """Usuario con sus roles cargados."""
    model_config = ConfigDict(from_attributes=True)
    roles: list["UsuarioRolOut"] = []


#  USUARIO ROL  (schema ligero para embeber en UsuarioConRoles)
class UsuarioRolOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    rol_id: int
