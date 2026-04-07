"""
Repositorio: OrdenTrabajo.
Filtros por solicitud y sucursal.
"""

from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.orden_trabajo import OrdenTrabajo, EstadoOrden
from app.repositories.base import BaseRepository


class OrdenRepository(BaseRepository[OrdenTrabajo]):
    def __init__(self, session: AsyncSession):
        super().__init__(OrdenTrabajo, session)

    async def get_by_solicitud(
        self,
        solicitud_id: int,
    ) -> Sequence[OrdenTrabajo]:
        """Obtiene todas las órdenes de una solicitud."""
        stmt = (
            select(OrdenTrabajo)
            .where(OrdenTrabajo.solicitud_id == solicitud_id)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_by_sucursal(
        self,
        sucursal_id: int,
        *,
        estado: EstadoOrden | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[OrdenTrabajo]:
        """Obtiene órdenes de una sucursal, opcionalmente filtradas por estado."""
        stmt = (
            select(OrdenTrabajo)
            .where(OrdenTrabajo.sucursal_id == sucursal_id)
        )
        if estado:
            stmt = stmt.where(OrdenTrabajo.estado == estado)
        stmt = stmt.offset(skip).limit(limit)
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_detallada(self, orden_id: int) -> OrdenTrabajo | None:
        """Obtiene una orden con sus detalles y pago precargados."""
        stmt = (
            select(OrdenTrabajo)
            .options(
                selectinload(OrdenTrabajo.detalles),
                selectinload(OrdenTrabajo.pago),
            )
            .where(OrdenTrabajo.id == orden_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def actualizar_estado(
        self,
        orden_id: int,
        nuevo_estado: EstadoOrden,
    ) -> OrdenTrabajo | None:
        """Actualiza el estado de una orden de trabajo."""
        return await self.update(orden_id, {"estado": nuevo_estado})
