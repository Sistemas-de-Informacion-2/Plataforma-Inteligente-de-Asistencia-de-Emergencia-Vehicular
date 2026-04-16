# backend/app/schemas/admin.py
"""
Schemas Pydantic: Admin.
"""
from pydantic import BaseModel, ConfigDict

class AdminBase(BaseModel):
    disponible: bool = True

class AdminCreate(AdminBase):
    """Requiere el usuario base al que extiende."""
    usuario_id: int

class AdminUpdate(BaseModel):
    disponible: bool | None = None

class AdminOut(AdminBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    usuario_id: int
