# backend/app/models/resena.py
"""
Modelo: ResenaForo.
Reseñas y calificaciones de sucursales por parte de los usuarios.
"""
from datetime import datetime
from sqlalchemy import Integer, ForeignKey, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base


class ResenaForo(Base):
    __tablename__ = "resenas_foro"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    puntuacion: Mapped[int] = mapped_column(Integer, nullable=False)  # 1-5
    comentario: Mapped[str | None] = mapped_column(Text)
    archivos_adjuntos: Mapped[str | None] = mapped_column(Text)  # URLs separadas por coma o JSON
    fecha: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # FK
    sucursal_id: Mapped[int] = mapped_column(
        ForeignKey("sucursales.id", ondelete="CASCADE"), nullable=False
    )
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    sucursal: Mapped["Sucursal"] = relationship(back_populates="resenas")
    usuario: Mapped["Usuario"] = relationship(back_populates="resenas")

    def __repr__(self) -> str:
        return f"<ResenaForo(id={self.id}, puntuacion={self.puntuacion})>"
