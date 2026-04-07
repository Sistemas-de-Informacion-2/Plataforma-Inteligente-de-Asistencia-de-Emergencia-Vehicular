"""
Modelo: Vehiculo.
Relación: Usuario 1:N Vehiculos.
"""

from sqlalchemy import String, Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Vehiculo(Base):
    __tablename__ = "vehiculos"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    marca: Mapped[str] = mapped_column(String(100), nullable=False)
    modelo: Mapped[str] = mapped_column(String(100), nullable=False)
    anio: Mapped[int] = mapped_column(Integer, nullable=False)
    placa: Mapped[str] = mapped_column(
        String(20), unique=True, index=True, nullable=False
    )

    # FK
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    propietario: Mapped["Usuario"] = relationship(back_populates="vehiculos")
    solicitudes: Mapped[list["SolicitudEmergencia"]] = relationship(
        back_populates="vehiculo"
    )

    def __repr__(self) -> str:
        return f"<Vehiculo(id={self.id}, placa='{self.placa}')>"
