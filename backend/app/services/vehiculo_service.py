"""
Servicio: Vehiculo.
CRUD de vehículos vinculados a un usuario.
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.vehiculo import Vehiculo
from app.repositories.vehiculo_repository import VehiculoRepository
from app.schemas.vehiculo import VehiculoCreate, VehiculoUpdate


class VehiculoService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = VehiculoRepository(session)

    async def crear(self, data: VehiculoCreate) -> Vehiculo:
        """Registra un nuevo vehículo. Valida unicidad de placa."""
        if await self.repo.placa_exists(data.placa):
            raise ValueError(f"La placa '{data.placa}' ya está registrada")
        return await self.repo.create(data.model_dump())

    async def obtener_por_id(self, vehiculo_id: int) -> Vehiculo | None:
        return await self.repo.get_by_id(vehiculo_id)

    async def listar_por_usuario(
        self,
        usuario_id: int,
        skip: int = 0,
        limit: int = 100,
    ) -> list[Vehiculo]:
        return list(await self.repo.get_by_usuario(usuario_id, skip=skip, limit=limit))

    async def actualizar(self, vehiculo_id: int, data: VehiculoUpdate) -> Vehiculo | None:
        update_data = data.model_dump(exclude_unset=True)
        if not update_data:
            return await self.repo.get_by_id(vehiculo_id)
        return await self.repo.update(vehiculo_id, update_data)

    async def eliminar(self, vehiculo_id: int) -> bool:
        return await self.repo.delete(vehiculo_id)
