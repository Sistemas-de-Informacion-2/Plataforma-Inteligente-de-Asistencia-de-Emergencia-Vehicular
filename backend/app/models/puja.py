# backend/app/models/puja.py
"""
Modelo: Puja.
Oferta de una sucursal para atender una solicitud de emergencia.
Flujo inDrive: el taller envía solo el precio, el backend calcula el ETA.
"""
import enum
from datetime import datetime

from sqlalchemy import Integer, Float, ForeignKey, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base


class EstadoPuja(str, enum.Enum):
    """Estados posibles de una puja."""
    PENDIENTE = "PENDIENTE"    # Enviada, esperando decisión del cliente
    ACEPTADA = "ACEPTADA"      # El cliente eligió esta puja
    RECHAZADA = "RECHAZADA"    # Otra puja fue elegida, o la solicitud fue cancelada


class Puja(Base):
    __tablename__ = "pujas"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    # El taller solo envía esto:
    precio_estimado: Mapped[float] = mapped_column(Float, nullable=False)

    # Calculado por el backend con PostGIS (distancia / 30km/h * 60):
    tiempo_llegada_minutos: Mapped[int] = mapped_column(Integer, nullable=False)

    estado: Mapped[EstadoPuja] = mapped_column(
        SAEnum(EstadoPuja, name="estado_puja", create_constraint=True),
        default=EstadoPuja.PENDIENTE,
        nullable=False,
    )

    fecha: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # FK
    solicitud_id: Mapped[int] = mapped_column(
        ForeignKey("solicitudes_emergencia.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sucursal_id: Mapped[int] = mapped_column(
        ForeignKey("sucursales.id", ondelete="CASCADE"),
        nullable=False,
    )

    # ── Relaciones ────────────────────────────────────────────
    solicitud: Mapped["SolicitudEmergencia"] = relationship(
        back_populates="pujas"
    )
    sucursal: Mapped["Sucursal"] = relationship(
        back_populates="pujas"
    )

    def __repr__(self) -> str:
        return (
            f"<Puja(id={self.id}, precio={self.precio_estimado}, "
            f"eta={self.tiempo_llegada_minutos}min, estado='{self.estado}')>"
        )
