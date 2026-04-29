# backend/app/repositories/rol_repository.py
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.rol import Rol, Permiso, RolPermiso

class RolRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_all_roles(self) -> list[Rol]:
        stmt = select(Rol).options(selectinload(Rol.permisos).selectinload(RolPermiso.permiso)).order_by(Rol.id)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_rol_by_id(self, rol_id: int) -> Rol | None:
        stmt = select(Rol).options(selectinload(Rol.permisos).selectinload(RolPermiso.permiso)).where(Rol.id == rol_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_rol_by_nombre(self, nombre: str) -> Rol | None:
        stmt = select(Rol).where(Rol.nombre == nombre)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_rol(self, nombre: str, permisos_ids: list[int] = None) -> Rol:
        nuevo_rol = Rol(nombre=nombre)
        self.session.add(nuevo_rol)
        await self.session.flush()

        if permisos_ids:
            for p_id in set(permisos_ids):
                self.session.add(RolPermiso(rol_id=nuevo_rol.id, permiso_id=p_id))
        
        await self.session.commit()
        return await self.get_rol_by_id(nuevo_rol.id)

    async def update_rol(self, rol_id: int, nombre: str | None, permisos_ids: list[int] | None) -> Rol | None:
        rol = await self.get_rol_by_id(rol_id)
        if not rol:
            return None

        if nombre is not None:
            rol.nombre = nombre

        if permisos_ids is not None:
            # Eliminar todos los permisos actuales
            stmt_delete = delete(RolPermiso).where(RolPermiso.rol_id == rol_id)
            await self.session.execute(stmt_delete)
            # Agregar nuevos permisos
            for p_id in set(permisos_ids):
                self.session.add(RolPermiso(rol_id=rol_id, permiso_id=p_id))

        await self.session.commit()
        return await self.get_rol_by_id(rol_id)

    async def delete_rol(self, rol_id: int) -> bool:
        rol = await self.get_rol_by_id(rol_id)
        if not rol:
            return False
        await self.session.delete(rol)
        await self.session.commit()
        return True


class PermisoRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_all_permisos(self) -> list[Permiso]:
        stmt = select(Permiso).order_by(Permiso.id)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_permiso_by_id(self, permiso_id: int) -> Permiso | None:
        stmt = select(Permiso).where(Permiso.id == permiso_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()
