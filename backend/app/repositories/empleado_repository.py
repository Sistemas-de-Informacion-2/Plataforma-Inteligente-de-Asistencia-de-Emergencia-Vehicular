# backend/app/repositories/empleado_repository.py
"""
Repositorio: Empleado.
Filtrado por sucursal, disponibilidad y especialidad.
"""

from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.empleado import Empleado
from app.repositories.base import BaseRepository


class EmpleadoRepository(BaseRepository[Empleado]):
    def __init__(self, session: AsyncSession):
        super().__init__(Empleado, session)

    async def get_by_usuario(self, usuario_id: int) -> Empleado | None:
        """Obtiene el empleado vinculado a un usuario."""
        stmt = select(Empleado).where(Empleado.usuario_id == usuario_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_sucursal(
        self,
        sucursal_id: int,
        *,
        solo_disponibles: bool = False,
    ) -> Sequence[Empleado]:
        """Obtiene empleados de una sucursal, opcionalmente solo los disponibles."""
        stmt = select(Empleado).where(Empleado.sucursal_id == sucursal_id)
        if solo_disponibles:
            stmt = stmt.where(Empleado.disponible == True)  # noqa: E712
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_disponibles(
        self,
        *,
        sucursal_id: int | None = None,
        especialidad: str | None = None,
    ) -> Sequence[Empleado]:
        """
        Obtiene empleados disponibles, opcionalmente filtrados por
        sucursal y/o especialidad. Útil para el motor de asignación.
        """
        stmt = select(Empleado).where(Empleado.disponible == True)  # noqa: E712
        if sucursal_id is not None:
            stmt = stmt.where(Empleado.sucursal_id == sucursal_id)
        if especialidad is not None:
            stmt = stmt.where(Empleado.especialidad.ilike(f"%{especialidad}%"))
        result = await self.session.execute(stmt)
        return result.scalars().all()
