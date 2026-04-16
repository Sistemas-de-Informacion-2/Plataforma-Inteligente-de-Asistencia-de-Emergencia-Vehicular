# backend/app/repositories/empleado_repository.py
"""
Repositorio: Empleado (Técnico).
Filtrado por sucursal, disponibilidad, especialidad y Admin (tenant isolation).
"""
from typing import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.empleado import Empleado
from app.models.taller import Sucursal, Taller
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

    # TENANT-SCOPED QUERIES (solo empleados del taller del admin)
    async def get_by_admin(
        self,
        admin_id: int,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Empleado]:
        """
        Retorna SOLO los empleados que pertenecen a sucursales
        del taller administrado por admin_id.
        Previene Data Leaks entre administradores (Tenant Isolation).
        """
        stmt = (
            select(Empleado)
            .join(Sucursal, Empleado.sucursal_id == Sucursal.id)
            .join(Taller, Sucursal.taller_id == Taller.id)
            .where(
                Taller.admin_id == admin_id,
                Taller.es_eliminado == False,
                Sucursal.es_eliminado == False,
                Empleado.es_eliminado == False,
            )
            .options(
                selectinload(Empleado.usuario),
                selectinload(Empleado.sucursal),
            )
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_by_id_scoped(
        self, empleado_id: int, admin_id: int
    ) -> Empleado | None:
        """
        Obtiene un empleado por ID verificando que pertenezca
        al taller del admin. Devuelve None si no es suyo (403-safe).
        """
        stmt = (
            select(Empleado)
            .join(Sucursal, Empleado.sucursal_id == Sucursal.id)
            .join(Taller, Sucursal.taller_id == Taller.id)
            .where(
                Empleado.id == empleado_id,
                Taller.admin_id == admin_id,
                Taller.es_eliminado == False,
                Sucursal.es_eliminado == False,
                Empleado.es_eliminado == False,
            )
            .options(
                selectinload(Empleado.usuario),
                selectinload(Empleado.sucursal),
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_all(
        self,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Empleado]:
        """Obtiene empleados con usuario y sucursal. (Uso interno / superadmin)"""
        stmt = (
            select(Empleado)
            .options(
                selectinload(Empleado.usuario),
                selectinload(Empleado.sucursal)
            )
            .offset(skip)
            .limit(limit)
        )
        if hasattr(Empleado, "es_eliminado"):
            stmt = stmt.where(Empleado.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalars().all()
