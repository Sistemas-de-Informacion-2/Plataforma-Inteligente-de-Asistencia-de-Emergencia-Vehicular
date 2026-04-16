# backend/app/repositories/servicio_repository.py
"""
Repositorio: Servicio (Catálogo Maestro).
CRUD estándar heredado de BaseRepository.
Solo el SUPER_ADMIN gestiona este catálogo.
"""
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.servicio import Servicio
from app.repositories.base import BaseRepository


class ServicioRepository(BaseRepository[Servicio]):
    def __init__(self, session: AsyncSession):
        super().__init__(Servicio, session)
