"""
Repositorio: Pago.
Filtrado por orden y estado.
"""

from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pago import Pago, EstadoPago
from app.repositories.base import BaseRepository


class PagoRepository(BaseRepository[Pago]):
    def __init__(self, session: AsyncSession):
        super().__init__(Pago, session)

    async def get_by_orden(self, orden_id: int) -> Pago | None:
        """Obtiene el pago asociado a una orden de trabajo (1:1)."""
        stmt = select(Pago).where(Pago.orden_id == orden_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_estado(
        self,
        estado: EstadoPago,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Pago]:
        """Obtiene pagos filtrados por estado."""
        stmt = (
            select(Pago)
            .where(Pago.estado == estado)
            .order_by(Pago.fecha.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()
