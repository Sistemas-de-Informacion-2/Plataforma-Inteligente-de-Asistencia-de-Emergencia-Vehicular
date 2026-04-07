"""
Modelos: OrdenTrabajo y DetalleOrden.
"""

import enum
from datetime import datetime

from sqlalchemy import String, Float, ForeignKey, Text, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base


class EstadoOrden(str, enum.Enum):
    """Estados posibles de una orden de trabajo."""
    CREADA = "CREADA"
    EN_PROGRESO = "EN_PROGRESO"
    COMPLETADA = "COMPLETADA"
    CANCELADA = "CANCELADA"


class OrdenTrabajo(Base):
    __tablename__ = "ordenes_trabajo"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    estado: Mapped[EstadoOrden] = mapped_column(
        SAEnum(EstadoOrden, name="estado_orden", create_constraint=True),
        default=EstadoOrden.CREADA,
        nullable=False,
    )
    fecha_inicio: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    fecha_fin: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # FK
    solicitud_id: Mapped[int] = mapped_column(
        ForeignKey("solicitudes_emergencia.id", ondelete="CASCADE"), nullable=False
    )
    sucursal_id: Mapped[int] = mapped_column(
        ForeignKey("sucursales.id", ondelete="SET NULL"), nullable=True
    )

    # Relaciones
    solicitud: Mapped["SolicitudEmergencia"] = relationship(
        back_populates="ordenes"
    )
    sucursal: Mapped["Sucursal"] = relationship(back_populates="ordenes")
    detalles: Mapped[list["DetalleOrden"]] = relationship(
        back_populates="orden", cascade="all, delete-orphan"
    )
    pago: Mapped["Pago"] = relationship(
        back_populates="orden", uselist=False, cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<OrdenTrabajo(id={self.id}, estado='{self.estado}')>"


class DetalleOrden(Base):
    __tablename__ = "detalles_orden"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    descripcion: Mapped[str] = mapped_column(Text, nullable=False)
    costo: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    # FK
    orden_id: Mapped[int] = mapped_column(
        ForeignKey("ordenes_trabajo.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    orden: Mapped["OrdenTrabajo"] = relationship(back_populates="detalles")

    def __repr__(self) -> str:
        return f"<DetalleOrden(id={self.id}, costo={self.costo})>"
