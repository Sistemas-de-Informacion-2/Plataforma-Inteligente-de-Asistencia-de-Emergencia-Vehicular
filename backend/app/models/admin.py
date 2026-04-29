# backend/app/models/admin.py
"""
Modelo: Admin.
Extiende Usuario via FK 1:1. Administra uno o más talleres.
"""
from sqlalchemy import Boolean, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base

class Admin(Base):
    __tablename__ = "admins"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    disponible: Mapped[bool] = mapped_column(Boolean, default=True)
    deuda_comision: Mapped[float] = mapped_column(
        Float, default=0.0, nullable=False,
        comment="Deuda acumulada de comisiones no pagadas (pagos en efectivo). Límite: 150 Bs."
    )
    qr_imagen_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # FK — vincula al usuario base
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"), unique=True, nullable=False
    )

    # Relaciones
    usuario: Mapped["Usuario"] = relationship("Usuario")
    talleres: Mapped[list["Taller"]] = relationship(
        back_populates="admin", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Admin(id={self.id}, usuario_id={self.usuario_id})>"
