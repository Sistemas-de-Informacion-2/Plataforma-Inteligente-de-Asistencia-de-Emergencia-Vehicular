"""
Modelo: DiagnosticoIA.
Resultado del análisis automático de un incidente.
"""

import enum
from datetime import datetime

from sqlalchemy import String, Float, ForeignKey, Text, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base


class NivelGravedad(str, enum.Enum):
    """Nivel de gravedad determinado por la IA."""
    LEVE = "LEVE"
    MEDIO = "MEDIO"
    GRAVE = "GRAVE"
    CRITICO = "CRITICO"


class Prioridad(str, enum.Enum):
    """Prioridad de atención."""
    BAJA = "BAJA"
    MEDIA = "MEDIA"
    ALTA = "ALTA"
    URGENTE = "URGENTE"


class DiagnosticoIA(Base):
    __tablename__ = "diagnosticos_ia"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    problema_detectado: Mapped[str] = mapped_column(Text, nullable=False)
    nivel_gravedad: Mapped[NivelGravedad] = mapped_column(
        SAEnum(NivelGravedad, name="nivel_gravedad", create_constraint=True),
        nullable=False,
    )
    costo_estimado_ia: Mapped[float | None] = mapped_column(Float)
    fecha: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    prioridad: Mapped[Prioridad] = mapped_column(
        SAEnum(Prioridad, name="prioridad", create_constraint=True),
        nullable=False,
    )

    # FK — relación 1:1 con solicitud
    solicitud_id: Mapped[int] = mapped_column(
        ForeignKey("solicitudes_emergencia.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    # Relaciones
    solicitud: Mapped["SolicitudEmergencia"] = relationship(
        back_populates="diagnostico"
    )

    def __repr__(self) -> str:
        return (
            f"<DiagnosticoIA(id={self.id}, problema='{self.problema_detectado[:30]}')>"
        )
