# backend/app/repositories/vehiculo_repository.py
"""
Repositorio: Vehiculo.
Filtrado por usuario propietario.
"""
from typing import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.vehiculo import Vehiculo
from app.repositories.base import BaseRepository


class VehiculoRepository(BaseRepository[Vehiculo]):
    def __init__(self, session: AsyncSession):
        super().__init__(Vehiculo, session)

    async def get_by_usuario(
        self,
        usuario_id: int,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Vehiculo]:
        """Obtiene todos los vehículos de un usuario."""
        stmt = (
            select(Vehiculo)
            .where(Vehiculo.usuario_id == usuario_id)
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_by_placa(self, placa: str) -> Vehiculo | None:
        """Busca un vehículo por su placa (única)."""
        stmt = select(Vehiculo).where(Vehiculo.placa == placa)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def placa_exists(self, placa: str) -> bool:
        """Verifica si una placa ya está registrada."""
        v = await self.get_by_placa(placa)
        return v is not None
