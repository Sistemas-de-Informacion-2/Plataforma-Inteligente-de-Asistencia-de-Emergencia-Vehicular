"""
Schemas Pydantic: Notificacion.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificacionBase(BaseModel):
    mensaje: str


class NotificacionCreate(NotificacionBase):
    """Crear una notificación para un usuario."""
    usuario_id: int


class NotificacionUpdate(BaseModel):
    """Solo se puede actualizar el estado de lectura."""
    leido: bool


class NotificacionOut(NotificacionBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    leido: bool
    fecha: datetime
    usuario_id: int
