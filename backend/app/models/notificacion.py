# backend/app/models/notificacion.py
"""
Modelo: Notificacion.
Notificaciones push dirigidas a un usuario específico.
"""

from datetime import datetime

from sqlalchemy import Boolean, ForeignKey, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Notificacion(Base):
    __tablename__ = "notificaciones"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    mensaje: Mapped[str] = mapped_column(Text, nullable=False)
    leido: Mapped[bool] = mapped_column(Boolean, default=False)
    fecha: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # FK
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    usuario: Mapped["Usuario"] = relationship(back_populates="notificaciones")

    def __repr__(self) -> str:
        return f"<Notificacion(id={self.id}, leido={self.leido})>"
