# backend/app/models/sos_notificacion_sucursal.py
"""
Modelo: SosNotificacionSucursal.
Registra cada broadcast SOS enviado a una sucursal cercana.
Permite calcular la tasa de aceptación (KPI 2 y KPI 6).
"""
from datetime import datetime

from sqlalchemy import ForeignKey, DateTime, Boolean, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class SosNotificacionSucursal(Base):
    __tablename__ = "sos_notificaciones_sucursal"

    __table_args__ = (
        UniqueConstraint(
            "solicitud_id", "sucursal_id",
            name="uq_sos_notif_solicitud_sucursal",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    solicitud_id: Mapped[int] = mapped_column(
        ForeignKey("solicitudes_emergencia.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sucursal_id: Mapped[int] = mapped_column(
        ForeignKey("sucursales.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    fecha_envio: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    respondio: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False, server_default="false"
    )

    solicitud: Mapped["SolicitudEmergencia"] = relationship()
    sucursal: Mapped["Sucursal"] = relationship(
        back_populates="sos_notificaciones"
    )

    def __repr__(self) -> str:
        return (
            f"<SosNotificacionSucursal("
            f"solicitud={self.solicitud_id}, sucursal={self.sucursal_id}, "
            f"respondio={self.respondio})>"
        )
