"""
Modelo: Admin.
Extiende Usuario via FK 1:1. Administra uno o más talleres.
"""

from sqlalchemy import Boolean, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Admin(Base):
    __tablename__ = "admins"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    disponible: Mapped[bool] = mapped_column(Boolean, default=True)

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
