"""
Repositorio: Evidencia.
Filtrado por solicitud y tipo.
"""

from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.evidencia import Evidencia, TipoEvidencia
from app.repositories.base import BaseRepository


class EvidenciaRepository(BaseRepository[Evidencia]):
    def __init__(self, session: AsyncSession):
        super().__init__(Evidencia, session)

    async def get_by_solicitud(
        self,
        solicitud_id: int,
    ) -> Sequence[Evidencia]:
        """Obtiene todas las evidencias de una solicitud."""
        stmt = (
            select(Evidencia)
            .where(Evidencia.solicitud_id == solicitud_id)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_by_tipo(
        self,
        solicitud_id: int,
        tipo: TipoEvidencia,
    ) -> Sequence[Evidencia]:
        """Obtiene evidencias de un tipo específico para una solicitud."""
        stmt = (
            select(Evidencia)
            .where(
                Evidencia.solicitud_id == solicitud_id,
                Evidencia.tipo == tipo,
            )
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_imagenes(self, solicitud_id: int) -> Sequence[Evidencia]:
        """Atajo: obtiene solo las imágenes de una solicitud."""
        return await self.get_by_tipo(solicitud_id, TipoEvidencia.IMAGEN)

    async def get_audios(self, solicitud_id: int) -> Sequence[Evidencia]:
        """Atajo: obtiene solo los audios de una solicitud."""
        return await self.get_by_tipo(solicitud_id, TipoEvidencia.AUDIO)
