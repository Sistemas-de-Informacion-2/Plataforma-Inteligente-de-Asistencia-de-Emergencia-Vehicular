# backend/app/models/auditable.py
"""
Patrón Mixin de Auditoría (Soft Delete).
Se aplica a modelos principales para evitar borrados físicos.
"""
from datetime import datetime
from sqlalchemy import Boolean, DateTime, func, text
from sqlalchemy.orm import Mapped, mapped_column

class AuditableMixin:
    """
    Proporciona campos universales de auditoría y Soft Delete.
    Se necesita usar explicitamente server_default='false' para que Alembic
    no rompa con registros existentes donde nullable=False.
    """
    fecha_creacion: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    fecha_actualizacion: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(), 
        onupdate=func.now(), 
        nullable=False
    )
    es_eliminado: Mapped[bool] = mapped_column(
        Boolean, server_default=text("false"), default=False, index=True, nullable=False
    )
    fecha_eliminacion: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
