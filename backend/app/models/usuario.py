"""
Modelo: Usuario y UsuarioPerfil.
Relaciones: Usuario 1:1 UsuarioPerfil, 1:N Vehiculos, M:N Roles (via UsuarioRol).
"""

from datetime import datetime, date

from sqlalchemy import String, DateTime, Date, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    nombre: Mapped[str] = mapped_column(String(100), nullable=False)
    email: Mapped[str] = mapped_column(
        String(150), unique=True, index=True, nullable=False
    )
    password: Mapped[str] = mapped_column(String(255), nullable=False)
    telefono: Mapped[str | None] = mapped_column(String(20))
    ci: Mapped[str] = mapped_column(
        String(20), unique=True, index=True, nullable=False
    )
    fecha_creacion: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # ── Relaciones ────────────────────────────────────────────
    perfil: Mapped["UsuarioPerfil"] = relationship(
        back_populates="usuario", uselist=False, cascade="all, delete-orphan"
    )
    vehiculos: Mapped[list["Vehiculo"]] = relationship(
        back_populates="propietario", cascade="all, delete-orphan"
    )
    roles: Mapped[list["UsuarioRol"]] = relationship(
        back_populates="usuario", cascade="all, delete-orphan"
    )
    notificaciones: Mapped[list["Notificacion"]] = relationship(
        back_populates="usuario", cascade="all, delete-orphan"
    )
    resenas: Mapped[list["ResenaForo"]] = relationship(
        back_populates="usuario", cascade="all, delete-orphan"
    )
    solicitudes: Mapped[list["SolicitudEmergencia"]] = relationship(
        back_populates="cliente", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Usuario(id={self.id}, email='{self.email}')>"


class UsuarioPerfil(Base):
    __tablename__ = "usuario_perfiles"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    segundo_nombre: Mapped[str | None] = mapped_column(String(100))
    apellidos: Mapped[str | None] = mapped_column(String(150))
    foto: Mapped[str | None] = mapped_column(Text)  # URL de la foto
    fecha_nacimiento: Mapped[date | None] = mapped_column(Date)

    # FK
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"), unique=True, nullable=False
    )

    # Relación inversa
    usuario: Mapped["Usuario"] = relationship(back_populates="perfil")

    def __repr__(self) -> str:
        return f"<UsuarioPerfil(usuario_id={self.usuario_id})>"