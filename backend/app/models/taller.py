"""
Modelos: Taller y Sucursal.
Sucursal usa GeoAlchemy2 para columna PostGIS de ubicación.
"""

from sqlalchemy import String, Float, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from geoalchemy2 import Geometry

from app.core.database import Base


class Taller(Base):
    __tablename__ = "talleres"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text)

    # FK — El admin que gestiona este taller
    admin_id: Mapped[int] = mapped_column(
        ForeignKey("admins.id", ondelete="SET NULL"), nullable=True
    )

    # Relaciones
    admin: Mapped["Admin"] = relationship(back_populates="talleres")
    sucursales: Mapped[list["Sucursal"]] = relationship(
        back_populates="taller", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Taller(id={self.id}, nombre='{self.nombre}')>"


class Sucursal(Base):
    __tablename__ = "sucursales"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    direccion: Mapped[str | None] = mapped_column(String(300))
    latitud: Mapped[float] = mapped_column(Float, nullable=False)
    longitud: Mapped[float] = mapped_column(Float, nullable=False)
    telefono: Mapped[str | None] = mapped_column(String(20))

    # Columna PostGIS para queries espaciales
    ubicacion = mapped_column(
        Geometry(geometry_type="POINT", srid=4326), nullable=True
    )

    # FK
    taller_id: Mapped[int] = mapped_column(
        ForeignKey("talleres.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    taller: Mapped["Taller"] = relationship(back_populates="sucursales")
    servicios: Mapped[list["SucursalServicio"]] = relationship(
        back_populates="sucursal", cascade="all, delete-orphan"
    )
    empleados: Mapped[list["Empleado"]] = relationship(
        back_populates="sucursal"
    )
    ordenes: Mapped[list["OrdenTrabajo"]] = relationship(
        back_populates="sucursal"
    )
    asignaciones: Mapped[list["Asignacion"]] = relationship(
        back_populates="sucursal"
    )
    resenas: Mapped[list["ResenaForo"]] = relationship(
        back_populates="sucursal"
    )

    def __repr__(self) -> str:
        return f"<Sucursal(id={self.id}, nombre='{self.nombre}')>"
