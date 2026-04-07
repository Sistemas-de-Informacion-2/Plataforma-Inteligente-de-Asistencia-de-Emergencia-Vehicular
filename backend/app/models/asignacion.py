"""
Modelo: Asignacion.
Vincula una SolicitudEmergencia con un Empleado y una Sucursal.
"""

import enum
from datetime import datetime

from sqlalchemy import String, Integer, Float, ForeignKey, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base


class EstadoAsignacion(str, enum.Enum):
    """Estados de una asignación de técnico."""
    PENDIENTE = "PENDIENTE"
    ACEPTADA = "ACEPTADA"
    RECHAZADA = "RECHAZADA"
    EN_CAMINO = "EN_CAMINO"
    EN_SITIO = "EN_SITIO"
    COMPLETADA = "COMPLETADA"


class Asignacion(Base):
    __tablename__ = "asignaciones"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    estado: Mapped[EstadoAsignacion] = mapped_column(
        SAEnum(EstadoAsignacion, name="estado_asignacion", create_constraint=True),
        default=EstadoAsignacion.PENDIENTE,
        nullable=False,
    )
    fecha: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    tiempo_estimado_llegada: Mapped[int | None] = mapped_column(
        Integer  # minutos estimados
    )

    # FK
    solicitud_id: Mapped[int] = mapped_column(
        ForeignKey("solicitudes_emergencia.id", ondelete="CASCADE"), nullable=False
    )
    empleado_id: Mapped[int] = mapped_column(
        ForeignKey("empleados.id", ondelete="SET NULL"), nullable=True
    )
    sucursal_id: Mapped[int] = mapped_column(
        ForeignKey("sucursales.id", ondelete="SET NULL"), nullable=True
    )

    # Relaciones
    solicitud: Mapped["SolicitudEmergencia"] = relationship(
        back_populates="asignaciones"
    )
    empleado: Mapped["Empleado"] = relationship(back_populates="asignaciones")
    sucursal: Mapped["Sucursal"] = relationship(back_populates="asignaciones")

    def __repr__(self) -> str:
        return f"<Asignacion(id={self.id}, estado='{self.estado}')>"
