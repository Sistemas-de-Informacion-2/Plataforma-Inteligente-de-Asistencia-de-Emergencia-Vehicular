"""
Modelos: Pago y MetodoPago.
El taller paga 10% de comisión a la plataforma.
"""

import enum
from datetime import datetime

from sqlalchemy import String, Float, ForeignKey, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base


class EstadoPago(str, enum.Enum):
    """Estados de un pago."""
    PENDIENTE = "PENDIENTE"
    COMPLETADO = "COMPLETADO"
    FALLIDO = "FALLIDO"
    REEMBOLSADO = "REEMBOLSADO"


class MetodoPago(Base):
    __tablename__ = "metodos_pago"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    nombre: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)

    # Relaciones
    pagos: Mapped[list["Pago"]] = relationship(back_populates="metodo_pago")

    def __repr__(self) -> str:
        return f"<MetodoPago(id={self.id}, nombre='{self.nombre}')>"


class Pago(Base):
    __tablename__ = "pagos"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    monto_total: Mapped[float] = mapped_column(Float, nullable=False)
    estado: Mapped[EstadoPago] = mapped_column(
        SAEnum(EstadoPago, name="estado_pago", create_constraint=True),
        default=EstadoPago.PENDIENTE,
        nullable=False,
    )
    fecha: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    comision: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0,
        comment="10% del monto total que cobra la plataforma"
    )
    monto_taller: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0,
        comment="90% del monto total que recibe el taller"
    )

    # FK
    orden_id: Mapped[int] = mapped_column(
        ForeignKey("ordenes_trabajo.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    metodo_pago_id: Mapped[int | None] = mapped_column(
        ForeignKey("metodos_pago.id", ondelete="SET NULL"), nullable=True
    )

    # Relaciones
    orden: Mapped["OrdenTrabajo"] = relationship(back_populates="pago")
    metodo_pago: Mapped["MetodoPago"] = relationship(back_populates="pagos")

    def __repr__(self) -> str:
        return f"<Pago(id={self.id}, monto={self.monto_total}, estado='{self.estado}')>"
