"""
Schemas Pydantic: ResenaForo.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ResenaBase(BaseModel):
    puntuacion: int = Field(..., ge=1, le=5)
    comentario: str | None = None
    archivos_adjuntos: str | None = None  # URLs separadas por coma o JSON


class ResenaCreate(ResenaBase):
    """Crear una reseña para una sucursal."""
    sucursal_id: int
    usuario_id: int


class ResenaUpdate(BaseModel):
    puntuacion: int | None = Field(None, ge=1, le=5)
    comentario: str | None = None
    archivos_adjuntos: str | None = None


class ResenaOut(ResenaBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    fecha: datetime
    sucursal_id: int
    usuario_id: int
