# backend/app/services/notificacion_service.py
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
        self, usuario_id: int, mensaje: str, data_push: dict | None = None
    ) -> Notificacion:
        """
        Atajo: crea y 'envía' una notificación con un mensaje simple.
        También intenta enviar push FCM como fallback.
        """
        notificacion = await self.repo.create({
            "usuario_id": usuario_id,
            "mensaje": mensaje,
        })

        # Push FCM como fallback (si el usuario tiene token registrado)
        try:
            from sqlalchemy import select
            from app.models.usuario import Usuario
            stmt = select(Usuario.fcm_token).where(Usuario.id == usuario_id)
            result = await self.session.execute(stmt)
            fcm_token = result.scalar_one_or_none()

            if fcm_token:
                from app.services.firebase_push_service import enviar_push
                from fastapi.concurrency import run_in_threadpool
                await run_in_threadpool(
                    enviar_push,
                    token_fcm=fcm_token,
                    titulo="Fixo - Emergencia Vehicular",
                    cuerpo=mensaje,
                    data=data_push or {"usuario_id": str(usuario_id)},
                )
        except Exception as e:
            import logging
            logging.getLogger(__name__).error(f"[Notificación] Error enviando push FCM: {e}")

        return notificacion

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
