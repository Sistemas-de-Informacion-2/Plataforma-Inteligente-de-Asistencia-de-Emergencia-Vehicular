"""
Schemas Pydantic: Taller y Sucursal.
"""

from pydantic import BaseModel, ConfigDict, Field


# ═══════════════════════════════════════════════════════════════
#  SUCURSAL
# ═══════════════════════════════════════════════════════════════

class SucursalBase(BaseModel):
    nombre: str = Field(..., max_length=150)
    direccion: str | None = Field(None, max_length=300)
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)
    telefono: str | None = Field(None, max_length=20)


class SucursalCreate(SucursalBase):
    """Requiere el ID del taller al que pertenece."""
    taller_id: int


class SucursalUpdate(BaseModel):
    nombre: str | None = Field(None, max_length=150)
    direccion: str | None = Field(None, max_length=300)
    latitud: float | None = Field(None, ge=-90, le=90)
    longitud: float | None = Field(None, ge=-180, le=180)
    telefono: str | None = Field(None, max_length=20)


class SucursalOut(SucursalBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    taller_id: int


class SucursalConDistancia(SucursalOut):
    """Sucursal con distancia calculada (para resultados de búsqueda geoespacial)."""
    distancia_km: float | None = None


# ═══════════════════════════════════════════════════════════════
#  TALLER
# ═══════════════════════════════════════════════════════════════

class TallerBase(BaseModel):
    nombre: str = Field(..., max_length=150)
    descripcion: str | None = None


class TallerCreate(TallerBase):
    """Opcionalmente vincula a un admin."""
    admin_id: int | None = None


class TallerUpdate(BaseModel):
    nombre: str | None = Field(None, max_length=150)
    descripcion: str | None = None
    admin_id: int | None = None


class TallerOut(TallerBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    admin_id: int | None = None


class TallerConSucursales(TallerOut):
    """Taller con sus sucursales anidadas."""
    model_config = ConfigDict(from_attributes=True)

    sucursales: list[SucursalOut] = []
