"""
Repositorio base genérico CRUD.
Usa SQLAlchemy 2.0 (select, session.execute) con async.
"""

from typing import Any, Generic, Sequence, Type, TypeVar

from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import Base

# TypeVar genérico vinculado a cualquier modelo que herede de Base
T = TypeVar("T", bound=Base)


class BaseRepository(Generic[T]):
    """
    Repositorio genérico con operaciones CRUD asíncronas.

    Uso:
        class UsuarioRepository(BaseRepository[Usuario]):
            def __init__(self, session: AsyncSession):
                super().__init__(Usuario, session)
    """

    def __init__(self, model: Type[T], session: AsyncSession):
        self.model = model
        self.session = session

    # ── READ ──────────────────────────────────────────────────

    async def get_by_id(self, id: int) -> T | None:
        """Obtiene un registro por su ID primario. Excluye soft deletes."""
        stmt = select(self.model).where(self.model.id == id)
        if hasattr(self.model, "es_eliminado"):
            stmt = stmt.where(self.model.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_all(
        self,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[T]:
        """Obtiene todos los registros con paginación. Excluye soft deletes."""
        stmt = select(self.model).offset(skip).limit(limit)
        if hasattr(self.model, "es_eliminado"):
            stmt = stmt.where(self.model.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_by_field(
        self,
        field_name: str,
        value: Any,
    ) -> T | None:
        """Obtiene un registro por un campo arbitrario (ej. email, ci)."""
        column = getattr(self.model, field_name, None)
        if column is None:
            raise ValueError(f"El modelo {self.model.__name__} no tiene el campo '{field_name}'")
        stmt = select(self.model).where(column == value)
        if hasattr(self.model, "es_eliminado"):
            stmt = stmt.where(self.model.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_many_by_field(
        self,
        field_name: str,
        value: Any,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[T]:
        """Obtiene múltiples registros filtrados por un campo."""
        column = getattr(self.model, field_name, None)
        if column is None:
            raise ValueError(f"El modelo {self.model.__name__} no tiene el campo '{field_name}'")
        stmt = (
            select(self.model)
            .where(column == value)
            .offset(skip)
            .limit(limit)
        )
        if hasattr(self.model, "es_eliminado"):
            stmt = stmt.where(self.model.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalars().all()

    # ── CREATE ────────────────────────────────────────────────

    async def create(self, data: dict[str, Any]) -> T:
        """
        Crea un nuevo registro a partir de un diccionario de datos.
        Hace flush para obtener el ID generado (el commit lo hace get_db).
        """
        instance = self.model(**data)
        self.session.add(instance)
        await self.session.flush()
        await self.session.refresh(instance)
        return instance

    # ── UPDATE ────────────────────────────────────────────────

    async def update(self, id: int, data: dict[str, Any]) -> T | None:
        """
        Actualiza un registro por ID con los campos proporcionados.
        Ignora claves con valor None.
        """
        # Filtrar valores None para no sobrescribir con nulos
        update_data = {k: v for k, v in data.items() if v is not None}
        if not update_data:
            return await self.get_by_id(id)

        stmt = (
            update(self.model)
            .where(self.model.id == id)
            .values(**update_data)
            .returning(self.model)
        )
        result = await self.session.execute(stmt)
        updated = result.scalar_one_or_none()

        if updated:
            await self.session.refresh(updated)

        return updated

    # ── DELETE ────────────────────────────────────────────────

    async def delete(self, id: int) -> bool:
        """Elimina un registro (lógico si tiene es_eliminado, físico de lo contrario). Retorna True si se afectó."""
        if hasattr(self.model, "es_eliminado"):
            from sqlalchemy.sql import func
            stmt = (
                update(self.model)
                .where(self.model.id == id)
                .values(es_eliminado=True, fecha_eliminacion=func.now())
            )
        else:
            stmt = delete(self.model).where(self.model.id == id)
            
        result = await self.session.execute(stmt)
        return result.rowcount > 0

    # ── COUNT ─────────────────────────────────────────────────

    async def count(self) -> int:
        """Cuenta el total de registros vivos."""
        from sqlalchemy import func
        stmt = select(func.count()).select_from(self.model)
        if hasattr(self.model, "es_eliminado"):
            stmt = stmt.where(self.model.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalar_one()
