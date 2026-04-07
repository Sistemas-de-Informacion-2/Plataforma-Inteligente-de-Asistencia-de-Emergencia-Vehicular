"""
Servicio: Notificación.
Creación, lectura y gestión de notificaciones push.
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notificacion import Notificacion
from app.repositories.notificacion_repository import NotificacionRepository
from app.schemas.notificacion import NotificacionCreate


class NotificacionService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = NotificacionRepository(session)

    async def crear(self, data: NotificacionCreate) -> Notificacion:
        """Crea una notificación para un usuario."""
        return await self.repo.create(data.model_dump())

    async def enviar_a_usuario(
        self, usuario_id: int, mensaje: str
    ) -> Notificacion:
        """Atajo: crea y 'envía' una notificación con un mensaje simple."""
        return await self.repo.create({
            "usuario_id": usuario_id,
            "mensaje": mensaje,
        })

    async def listar_por_usuario(
        self,
        usuario_id: int,
        solo_no_leidas: bool = False,
        skip: int = 0,
        limit: int = 50,
    ) -> list[Notificacion]:
        return list(
            await self.repo.get_by_usuario(
                usuario_id,
                solo_no_leidas=solo_no_leidas,
                skip=skip,
                limit=limit,
            )
        )

    async def marcar_como_leida(self, notificacion_id: int) -> Notificacion | None:
        return await self.repo.marcar_como_leida(notificacion_id)

    async def marcar_todas_leidas(self, usuario_id: int) -> int:
        """Marca todas como leídas. Retorna cantidad actualizada."""
        return await self.repo.marcar_todas_leidas(usuario_id)

    async def contar_no_leidas(self, usuario_id: int) -> int:
        return await self.repo.contar_no_leidas(usuario_id)
