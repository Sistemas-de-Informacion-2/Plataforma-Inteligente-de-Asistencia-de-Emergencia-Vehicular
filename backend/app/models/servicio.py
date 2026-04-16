# backend/app/models/servicio.py
"""
Modelos: Servicio (Especialidad) y SucursalServicio (M:N).
"""
from sqlalchemy import String, ForeignKey, UniqueConstraint, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


class Servicio(Base):
    """Tipo de servicio / especialidad que un taller puede ofrecer."""
    __tablename__ = "servicios"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    nombre: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text)

    # Relaciones
    sucursales: Mapped[list["SucursalServicio"]] = relationship(
        back_populates="servicio", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Servicio(id={self.id}, nombre='{self.nombre}')>"


class SucursalServicio(Base):
    """Tabla intermedia: Sucursal ↔ Servicio (M:N)."""
    __tablename__ = "sucursal_servicios"
    __table_args__ = (
        UniqueConstraint("sucursal_id", "servicio_id", name="uq_sucursal_servicio"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    sucursal_id: Mapped[int] = mapped_column(
        ForeignKey("sucursales.id", ondelete="CASCADE"), nullable=False
    )
    servicio_id: Mapped[int] = mapped_column(
        ForeignKey("servicios.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    sucursal: Mapped["Sucursal"] = relationship(back_populates="servicios")
    servicio: Mapped["Servicio"] = relationship(back_populates="sucursales")
