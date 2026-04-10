"""
Modelo: SolicitudEmergencia.
Enum de estados. Usa GeoAlchemy2 para ubicación del incidente.
"""

import enum
from datetime import datetime

from sqlalchemy import String, Float, ForeignKey, Text, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from geoalchemy2 import Geometry

from app.core.database import Base
from app.models.auditable import AuditableMixin


class EstadoSolicitud(str, enum.Enum):
    """Estados posibles de una solicitud de emergencia."""
    PENDIENTE = "PENDIENTE"
    EN_PROCESO = "EN_PROCESO"
    ATENDIDO = "ATENDIDO"
    CANCELADO = "CANCELADO"


class SolicitudEmergencia(AuditableMixin, Base):
    __tablename__ = "solicitudes_emergencia"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    descripcion: Mapped[str | None] = mapped_column(Text)
    latitud: Mapped[float] = mapped_column(Float, nullable=False)
    longitud: Mapped[float] = mapped_column(Float, nullable=False)
    estado: Mapped[EstadoSolicitud] = mapped_column(
        SAEnum(EstadoSolicitud, name="estado_solicitud", create_constraint=True),
        default=EstadoSolicitud.PENDIENTE,
        nullable=False,
    )

    # Columna PostGIS para queries espaciales
    ubicacion = mapped_column(
        Geometry(geometry_type="POINT", srid=4326), nullable=True
    )

    # FK
    cliente_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    vehiculo_id: Mapped[int | None] = mapped_column(
        ForeignKey("vehiculos.id", ondelete="SET NULL"), nullable=True
    )

    # ── Relaciones ────────────────────────────────────────────
    cliente: Mapped["Usuario"] = relationship(back_populates="solicitudes")
    vehiculo: Mapped["Vehiculo"] = relationship(back_populates="solicitudes")
    evidencias: Mapped[list["Evidencia"]] = relationship(
        back_populates="solicitud", cascade="all, delete-orphan"
    )
    diagnostico: Mapped["DiagnosticoIA"] = relationship(
        back_populates="solicitud", uselist=False, cascade="all, delete-orphan"
    )
    ordenes: Mapped[list["OrdenTrabajo"]] = relationship(
        back_populates="solicitud", cascade="all, delete-orphan"
    )
    asignaciones: Mapped[list["Asignacion"]] = relationship(
        back_populates="solicitud", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<SolicitudEmergencia(id={self.id}, estado='{self.estado}')>"
