# backend/app/repositories/notificacion_repository.py
"""
Repositorio: Notificacion.
Filtrado por usuario y estado de lectura.
"""

from typing import Sequence

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notificacion import Notificacion
from app.repositories.base import BaseRepository


class NotificacionRepository(BaseRepository[Notificacion]):
    def __init__(self, session: AsyncSession):
        super().__init__(Notificacion, session)

    async def get_by_usuario(
        self,
        usuario_id: int,
        *,
        solo_no_leidas: bool = False,
        skip: int = 0,
        limit: int = 50,
    ) -> Sequence[Notificacion]:
        """Obtiene notificaciones de un usuario, opcionalmente solo las no leídas."""
        stmt = (
            select(Notificacion)
            .where(Notificacion.usuario_id == usuario_id)
        )
        if solo_no_leidas:
            stmt = stmt.where(Notificacion.leido == False)  # noqa: E712

        stmt = stmt.order_by(Notificacion.fecha.desc()).offset(skip).limit(limit)
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def marcar_como_leida(self, notificacion_id: int) -> Notificacion | None:
        """Marca una notificación como leída."""
        return await self.update(notificacion_id, {"leido": True})

    async def marcar_todas_leidas(self, usuario_id: int) -> int:
        """Marca todas las notificaciones de un usuario como leídas. Retorna cantidad actualizada."""
        stmt = (
            update(Notificacion)
            .where(
                Notificacion.usuario_id == usuario_id,
                Notificacion.leido == False,  # noqa: E712
            )
            .values(leido=True)
        )
        result = await self.session.execute(stmt)
        return result.rowcount

    async def contar_no_leidas(self, usuario_id: int) -> int:
        """Cuenta las notificaciones no leídas de un usuario."""
        from sqlalchemy import func
        stmt = (
            select(func.count())
            .select_from(Notificacion)
            .where(
                Notificacion.usuario_id == usuario_id,
                Notificacion.leido == False,  # noqa: E712
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one()
