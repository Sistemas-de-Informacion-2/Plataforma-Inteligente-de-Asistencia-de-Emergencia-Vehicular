# backend/app/services/taller_service.py
"""
Servicio: Taller y Sucursal.
CRUD + gestión de sucursales con geolocalización.
"""

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.elements import WKTElement

from app.models.taller import Taller, Sucursal
from app.repositories.taller_repository import TallerRepository, SucursalRepository
from app.schemas.taller import (
    TallerCreate,
    TallerUpdate,
    SucursalCreate,
    SucursalUpdate,
)


class TallerService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = TallerRepository(session)

    async def crear(self, data: TallerCreate) -> Taller:
        return await self.repo.create(data.model_dump())

    async def obtener_por_id(self, taller_id: int) -> Taller | None:
        return await self.repo.get_by_id(taller_id)

    async def obtener_con_sucursales(self, taller_id: int) -> Taller | None:
        return await self.repo.get_with_sucursales(taller_id)

    async def listar(self, skip: int = 0, limit: int = 100) -> list[Taller]:
        return list(await self.repo.get_all(skip=skip, limit=limit))

    async def listar_por_admin(self, admin_id: int) -> list[Taller]:
        return list(await self.repo.get_by_admin(admin_id))

    async def actualizar(self, taller_id: int, data: TallerUpdate) -> Taller | None:
        update_data = data.model_dump(exclude_unset=True)
        if not update_data:
            return await self.repo.get_by_id(taller_id)
        return await self.repo.update(taller_id, update_data)

    async def eliminar(self, taller_id: int) -> bool:
        return await self.repo.delete(taller_id)


class SucursalService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = SucursalRepository(session)

    async def crear(self, data: SucursalCreate) -> Sucursal:
        """
        Crea una sucursal y genera automáticamente la columna
        PostGIS 'ubicacion' a partir de lat/lng.
        """
        sucursal_data = data.model_dump()

        # Generar geometría PostGIS a partir de lat/lng
        sucursal_data["ubicacion"] = WKTElement(
            f"POINT({data.longitud} {data.latitud})", srid=4326
        )

        return await self.repo.create(sucursal_data)

    async def obtener_por_id(self, sucursal_id: int) -> Sucursal | None:
        return await self.repo.get_by_id(sucursal_id)

    async def listar_por_taller(
        self,
        taller_id: int,
        skip: int = 0,
        limit: int = 100,
    ) -> list[Sucursal]:
        return list(
            await self.repo.get_by_taller(taller_id, skip=skip, limit=limit)
        )

    async def buscar_cercanas(
        self,
        latitud: float,
        longitud: float,
        radio_km: float = 10.0,
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        """
        Busca sucursales cercanas a un punto.
        Retorna: [{"sucursal": Sucursal, "distancia_km": float}, ...]
        """
        return await self.repo.buscar_cercanas(
            latitud, longitud, radio_km, limit=limit
        )

    async def actualizar(
        self, sucursal_id: int, data: SucursalUpdate
    ) -> Sucursal | None:
        update_data = data.model_dump(exclude_unset=True)

        # Si se actualizan coordenadas, regenerar la geometría
        if "latitud" in update_data or "longitud" in update_data:
            sucursal = await self.repo.get_by_id(sucursal_id)
            if sucursal:
                lat = update_data.get("latitud", sucursal.latitud)
                lng = update_data.get("longitud", sucursal.longitud)
                update_data["ubicacion"] = WKTElement(
                    f"POINT({lng} {lat})", srid=4326
                )

        if not update_data:
            return await self.repo.get_by_id(sucursal_id)
        return await self.repo.update(sucursal_id, update_data)

    async def eliminar(self, sucursal_id: int) -> bool:
        return await self.repo.delete(sucursal_id)

    async def obtener_servicios_asignados(self, sucursal_id: int):
        return await self.repo.obtener_servicios_de_sucursal(sucursal_id)

    async def asignar_servicio(self, sucursal_id: int, servicio_id: int, admin_id: int) -> None:
        from app.repositories.taller_repository import TallerRepository
        taller_repo = TallerRepository(self.session)
        sucursales_propias = await taller_repo.get_sucursal_ids_by_admin(admin_id)
        if sucursal_id not in sucursales_propias:
            raise ValueError("Esta sucursal no te pertenece")
        await self.repo.agregar_servicio_a_sucursal(sucursal_id, servicio_id)

    async def quitar_servicio(self, sucursal_id: int, servicio_id: int, admin_id: int) -> None:
        from app.repositories.taller_repository import TallerRepository
        taller_repo = TallerRepository(self.session)
        sucursales_propias = await taller_repo.get_sucursal_ids_by_admin(admin_id)
        if sucursal_id not in sucursales_propias:
            raise ValueError("Esta sucursal no te pertenece")
        await self.repo.quitar_servicio_de_sucursal(sucursal_id, servicio_id)
