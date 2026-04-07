"""
Servicio: Empleado (Técnico).
CRUD + gestión de disponibilidad.
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.empleado import Empleado
from app.repositories.empleado_repository import EmpleadoRepository
from app.schemas.empleado import EmpleadoCreate, EmpleadoUpdate


class EmpleadoService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = EmpleadoRepository(session)

    async def crear(self, data: EmpleadoCreate) -> Empleado:
        return await self.repo.create(data.model_dump())

    async def obtener_por_id(self, empleado_id: int) -> Empleado | None:
        return await self.repo.get_by_id(empleado_id)

    async def obtener_por_usuario(self, usuario_id: int) -> Empleado | None:
        return await self.repo.get_by_usuario(usuario_id)

    async def listar_por_sucursal(
        self,
        sucursal_id: int,
        solo_disponibles: bool = False,
    ) -> list[Empleado]:
        return list(
            await self.repo.get_by_sucursal(
                sucursal_id, solo_disponibles=solo_disponibles
            )
        )

    async def listar_disponibles(
        self,
        sucursal_id: int | None = None,
        especialidad: str | None = None,
    ) -> list[Empleado]:
        return list(
            await self.repo.get_disponibles(
                sucursal_id=sucursal_id, especialidad=especialidad
            )
        )

    async def actualizar(
        self, empleado_id: int, data: EmpleadoUpdate
    ) -> Empleado | None:
        update_data = data.model_dump(exclude_unset=True)
        if not update_data:
            return await self.repo.get_by_id(empleado_id)
        return await self.repo.update(empleado_id, update_data)

    async def cambiar_disponibilidad(
        self, empleado_id: int, disponible: bool
    ) -> Empleado | None:
        """Atajo: marcar un técnico como disponible/no disponible."""
        return await self.repo.update(empleado_id, {"disponible": disponible})

    async def actualizar_ubicacion(
        self, empleado_id: int, latitud: float, longitud: float
    ) -> Empleado | None:
        """Actualiza la ubicación GPS del técnico en movimiento."""
        return await self.repo.update(
            empleado_id, {"latitud": latitud, "longitud": longitud}
        )

    async def eliminar(self, empleado_id: int) -> bool:
        return await self.repo.delete(empleado_id)
