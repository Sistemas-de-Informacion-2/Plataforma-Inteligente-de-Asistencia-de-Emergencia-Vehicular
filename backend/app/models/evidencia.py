# backend/app/models/evidencia.py
"""
Modelo: Evidencia (imagen, audio, texto adjunto a una solicitud).
"""

import enum

from sqlalchemy import String, ForeignKey, Text, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class TipoEvidencia(str, enum.Enum):
    """Tipos de evidencia que puede adjuntar un usuario."""
    IMAGEN = "IMAGEN"
    AUDIO = "AUDIO"
    TEXTO = "TEXTO"


class Evidencia(Base):
    __tablename__ = "evidencias"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    tipo: Mapped[TipoEvidencia] = mapped_column(
        SAEnum(TipoEvidencia, name="tipo_evidencia", create_constraint=True),
        nullable=False,
    )
    url: Mapped[str] = mapped_column(Text, nullable=False)  # URL o contenido texto

    # FK
    solicitud_id: Mapped[int] = mapped_column(
        ForeignKey("solicitudes_emergencia.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    solicitud: Mapped["SolicitudEmergencia"] = relationship(
        back_populates="evidencias"
    )

    def __repr__(self) -> str:
        return f"<Evidencia(id={self.id}, tipo='{self.tipo}')>"
