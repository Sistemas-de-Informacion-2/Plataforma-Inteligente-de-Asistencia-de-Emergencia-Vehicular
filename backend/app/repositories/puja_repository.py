# backend/app/repositories/puja_repository.py
"""
Repositorio: Puja.
CRUD y queries específicas para el marketplace de pujas.
"""
from typing import Sequence
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.puja import Puja, EstadoPuja
from app.repositories.base import BaseRepository


class PujaRepository(BaseRepository[Puja]):
    def __init__(self, session: AsyncSession):
        super().__init__(Puja, session)

    async def get_by_solicitud(
        self,
        solicitud_id: int,
    ) -> Sequence[Puja]:
        """Obtiene todas las pujas de una solicitud, ordenadas por fecha."""
        stmt = (
            select(Puja)
            .where(Puja.solicitud_id == solicitud_id)
            .order_by(Puja.fecha.desc())
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_pendientes_by_solicitud(
        self,
        solicitud_id: int,
    ) -> Sequence[Puja]:
        """Obtiene solo las pujas PENDIENTES de una solicitud."""
        stmt = (
            select(Puja)
            .where(
                Puja.solicitud_id == solicitud_id,
                Puja.estado == EstadoPuja.PENDIENTE,
            )
            .order_by(Puja.fecha.asc())
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def ya_pujo_sucursal(
        self,
        solicitud_id: int,
        sucursal_id: int,
    ) -> bool:
        """Verifica si una sucursal ya envió una puja para esta solicitud."""
        stmt = (
            select(Puja.id)
            .where(
                Puja.solicitud_id == solicitud_id,
                Puja.sucursal_id == sucursal_id,
            )
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none() is not None

    async def aceptar_puja(self, puja_id: int) -> Puja | None:
        """Marca una puja como ACEPTADA."""
        return await self.update(puja_id, {"estado": EstadoPuja.ACEPTADA})

    async def rechazar_pujas_restantes(self, solicitud_id: int, puja_ganadora_id: int) -> int:
        """
        Rechaza todas las pujas PENDIENTES de una solicitud excepto la ganadora.
        Retorna la cantidad de pujas rechazadas.
        """
        stmt = (
            update(Puja)
            .where(
                Puja.solicitud_id == solicitud_id,
                Puja.id != puja_ganadora_id,
                Puja.estado == EstadoPuja.PENDIENTE,
            )
            .values(estado=EstadoPuja.RECHAZADA)
        )
        result = await self.session.execute(stmt)
        return result.rowcount
