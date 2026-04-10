"""
Repositorio: Usuario.
Búsquedas específicas por email y CI.
"""

from typing import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.usuario import Usuario, UsuarioPerfil
from app.repositories.base import BaseRepository


class UsuarioRepository(BaseRepository[Usuario]):
    def __init__(self, session: AsyncSession):
        super().__init__(Usuario, session)

    async def get_all(
        self,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Usuario]:
        """Obtiene usuarios con perfil precargado. Excluye eliminados."""
        stmt = (
            select(Usuario)
            .options(selectinload(Usuario.perfil))
            .where(Usuario.es_eliminado == False)
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_by_email(self, email: str) -> Usuario | None:
        """Busca un usuario por su email."""
        stmt = select(Usuario).where(Usuario.email == email, Usuario.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_ci(self, ci: str) -> Usuario | None:
        """Busca un usuario por su cédula de identidad."""
        stmt = select(Usuario).where(Usuario.ci == ci, Usuario.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_with_perfil(self, usuario_id: int) -> Usuario | None:
        """Obtiene un usuario con su perfil precargado (evita lazy loading)."""
        stmt = (
            select(Usuario)
            .options(selectinload(Usuario.perfil))
            .where(Usuario.id == usuario_id, Usuario.es_eliminado == False)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_with_roles(self, usuario_id: int) -> Usuario | None:
        """Obtiene un usuario con sus roles y perfil precargados."""
        stmt = (
            select(Usuario)
            .options(
                selectinload(Usuario.roles),
                selectinload(Usuario.perfil)
            )
            .where(Usuario.id == usuario_id, Usuario.es_eliminado == False)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def email_exists(self, email: str) -> bool:
        """Verifica si un email ya está registrado."""
        user = await self.get_by_email(email)
        return user is not None

    async def ci_exists(self, ci: str) -> bool:
        """Verifica si un CI ya está registrado."""
        user = await self.get_by_ci(ci)
        return user is not None
