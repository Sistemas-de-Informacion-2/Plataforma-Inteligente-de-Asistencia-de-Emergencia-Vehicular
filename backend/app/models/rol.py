# backend/app/models/rol.py
"""
Modelos: Rol, Permiso, RolPermiso (M:N) y UsuarioRol (M:N).
"""

from sqlalchemy import String, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Rol(Base):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    nombre: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

    # Relaciones
    permisos: Mapped[list["RolPermiso"]] = relationship(
        back_populates="rol", cascade="all, delete-orphan"
    )
    usuarios: Mapped[list["UsuarioRol"]] = relationship(
        back_populates="rol", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Rol(id={self.id}, nombre='{self.nombre}')>"


class Permiso(Base):
    __tablename__ = "permisos"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    nombre: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    descripcion: Mapped[str | None] = mapped_column(String(255))

    # Relaciones
    roles: Mapped[list["RolPermiso"]] = relationship(
        back_populates="permiso", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Permiso(id={self.id}, nombre='{self.nombre}')>"


class RolPermiso(Base):
    """Tabla intermedia: Rol ↔ Permiso (M:N)."""
    __tablename__ = "rol_permisos"
    __table_args__ = (
        UniqueConstraint("rol_id", "permiso_id", name="uq_rol_permiso"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    rol_id: Mapped[int] = mapped_column(
        ForeignKey("roles.id", ondelete="CASCADE"), nullable=False
    )
    permiso_id: Mapped[int] = mapped_column(
        ForeignKey("permisos.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    rol: Mapped["Rol"] = relationship(back_populates="permisos")
    permiso: Mapped["Permiso"] = relationship(back_populates="roles")


class UsuarioRol(Base):
    """Tabla intermedia: Usuario ↔ Rol (M:N)."""
    __tablename__ = "usuario_roles"
    __table_args__ = (
        UniqueConstraint("usuario_id", "rol_id", name="uq_usuario_rol"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    rol_id: Mapped[int] = mapped_column(
        ForeignKey("roles.id", ondelete="CASCADE"), nullable=False
    )

    # Relaciones
    usuario: Mapped["Usuario"] = relationship(back_populates="roles")
    rol: Mapped["Rol"] = relationship(back_populates="usuarios")
