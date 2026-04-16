# backend/app/schemas/diagnostico_ia.py
"""
Schemas Pydantic: DiagnosticoIA.
Los diagnósticos los genera la IA, por eso el Create incluye todos los campos
y no hay Update (los diagnósticos son inmutables).
"""
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
from app.models.diagnostico_ia import NivelGravedad, Prioridad


class DiagnosticoIABase(BaseModel):
    problema_detectado: str
    nivel_gravedad: NivelGravedad
    costo_estimado_ia: float | None = None
    prioridad: Prioridad


class DiagnosticoIACreate(DiagnosticoIABase):
    """Creado por el módulo de IA tras procesar evidencias."""
    solicitud_id: int


class DiagnosticoIAOut(DiagnosticoIABase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    fecha: datetime
    solicitud_id: int
