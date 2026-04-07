"""
Schemas Pydantic: Evidencia.
"""

from pydantic import BaseModel, ConfigDict, Field

from app.models.evidencia import TipoEvidencia


class EvidenciaBase(BaseModel):
    tipo: TipoEvidencia
    url: str = Field(..., min_length=1)


class EvidenciaCreate(EvidenciaBase):
    """Requiere el ID de la solicitud a la que pertenece."""
    solicitud_id: int


class EvidenciaOut(EvidenciaBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    solicitud_id: int
