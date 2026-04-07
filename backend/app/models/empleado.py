"""
Modelo: Empleado (Técnico).
Extiende Usuario via FK 1:1. Tiene ubicación GPS y pertenece a una Sucursal.
"""

from sqlalchemy import String, Boolean, Float, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Empleado(Base):
    __tablename__ = "empleados"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    especialidad: Mapped[str | None] = mapped_column(String(150))
    disponible: Mapped[bool] = mapped_column(Boolean, default=True)
    latitud: Mapped[float | None] = mapped_column(Float)
    longitud: Mapped[float | None] = mapped_column(Float)

    # FK — vincula al usuario base
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    # FK — sucursal donde trabaja
    sucursal_id: Mapped[int] = mapped_column(
        ForeignKey("sucursales.id", ondelete="SET NULL"), nullable=True
    )

    # Relaciones
    usuario: Mapped["Usuario"] = relationship("Usuario")
    sucursal: Mapped["Sucursal"] = relationship(back_populates="empleados")
    asignaciones: Mapped[list["Asignacion"]] = relationship(
        back_populates="empleado"
    )

    def __repr__(self) -> str:
        return f"<Empleado(id={self.id}, especialidad='{self.especialidad}')>"
