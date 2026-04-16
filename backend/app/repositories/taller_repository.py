# backend/app/repositories/taller_repository.py
"""
Repositorio: Taller y Sucursal.
Incluye búsqueda geoespacial con PostGIS (ST_DWithin).
"""
from typing import Any, Sequence
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from geoalchemy2.functions import ST_DWithin, ST_Distance
from geoalchemy2.elements import WKTElement
from app.models.taller import Taller, Sucursal
from app.repositories.base import BaseRepository


class TallerRepository(BaseRepository[Taller]):
    def __init__(self, session: AsyncSession):
        super().__init__(Taller, session)

    async def get_with_sucursales(self, taller_id: int) -> Taller | None:
        """Obtiene un taller con todas sus sucursales precargadas."""
        stmt = (
            select(Taller)
            .options(selectinload(Taller.sucursales))
            .where(Taller.id == taller_id, Taller.es_eliminado == False)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_admin(self, admin_id: int) -> Sequence[Taller]:
        """Obtiene todos los talleres administrados por un admin."""
        stmt = select(Taller).where(Taller.admin_id == admin_id, Taller.es_eliminado == False)
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_sucursal_ids_by_admin(self, admin_id: int) -> list[int]:
        """
        Retorna los IDs de TODAS las sucursales que pertenecen a los
        talleres de este admin. Usado para verificar ownership en PATCH/POST.
        """
        stmt = (
            select(Sucursal.id)
            .join(Taller, Sucursal.taller_id == Taller.id)
            .where(
                Taller.admin_id == admin_id,
                Taller.es_eliminado == False,
                Sucursal.es_eliminado == False,
            )
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())


class SucursalRepository(BaseRepository[Sucursal]):
    def __init__(self, session: AsyncSession):
        super().__init__(Sucursal, session)

    async def get_by_taller(
        self,
        taller_id: int,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Sucursal]:
        """Obtiene todas las sucursales de un taller."""
        stmt = (
            select(Sucursal)
            .where(Sucursal.taller_id == taller_id, Sucursal.es_eliminado == False)
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def buscar_cercanas(
        self,
        latitud: float,
        longitud: float,
        radio_km: float = 10.0,
        *,
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        """
        Busca sucursales dentro de un radio usando PostGIS ST_DWithin.
        Retorna una lista de dicts con la sucursal y la distancia en km.
        El radio se convierte de km a metros para ST_DWithin con geography.
        Args:
            latitud:   Latitud del punto de referencia (incidente)
            longitud:  Longitud del punto de referencia (incidente)
            radio_km:  Radio de búsqueda en kilómetros (default: 10)
            limit:     Máximo de resultados
        Returns:
            Lista de {"sucursal": Sucursal, "distancia_km": float}
        """
        radio_metros = radio_km * 1000

        from sqlalchemy import cast
        from geoalchemy2 import Geography

        # Crear punto de referencia con WKTElement y SRID 4326
        punto_ref = WKTElement(f"POINT({longitud} {latitud})", srid=4326)

        # Calcular distancia (usando cast correcto a TypeEngine Geography)
        distancia_expr = func.ST_Distance(
            cast(Sucursal.ubicacion, Geography),
            cast(punto_ref, Geography),
        )

        stmt = (
            select(Sucursal, distancia_expr.label("distancia_m"))
            .where(
                Sucursal.ubicacion.ST_DWithin(punto_ref, radio_metros)
            )
            .where(Sucursal.ubicacion.isnot(None), Sucursal.es_eliminado == False)
            .order_by(distancia_expr)
            .limit(limit)
            .execution_options(skip_user_space_cache=True)
        )

        result = await self.session.execute(stmt)
        rows = result.all()

        return [
            {
                "sucursal": row.Sucursal,
                "distancia_km": round(row.distancia_m / 1000, 2) if row.distancia_m else None,
            }
            for row in rows
        ]

    async def get_with_servicios(self, sucursal_id: int) -> Sucursal | None:
        """Obtiene una sucursal con sus servicios precargados."""
        stmt = (
            select(Sucursal)
            .options(selectinload(Sucursal.servicios))
            .where(Sucursal.id == sucursal_id, Sucursal.es_eliminado == False)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def obtener_servicios_de_sucursal(self, sucursal_id: int) -> Sequence:
        """Obtiene las relaciones SucursalServicio incluyendo la entidad Servicio."""
        from app.models.servicio import SucursalServicio, Servicio
        stmt = (
            select(SucursalServicio)
            .options(selectinload(SucursalServicio.servicio))
            .where(SucursalServicio.sucursal_id == sucursal_id)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def agregar_servicio_a_sucursal(self, sucursal_id: int, servicio_id: int) -> None:
        from app.models.servicio import SucursalServicio
        # Verificar existencia primero para evitar duplicados / errores
        stmt = select(SucursalServicio).where(
            SucursalServicio.sucursal_id == sucursal_id,
            SucursalServicio.servicio_id == servicio_id
        )
        result = await self.session.execute(stmt)
        if result.scalar_one_or_none() is None:
            asociacion = SucursalServicio(sucursal_id=sucursal_id, servicio_id=servicio_id)
            self.session.add(asociacion)
            await self.session.flush()

    async def quitar_servicio_de_sucursal(self, sucursal_id: int, servicio_id: int) -> None:
        from app.models.servicio import SucursalServicio
        stmt = select(SucursalServicio).where(
            SucursalServicio.sucursal_id == sucursal_id,
            SucursalServicio.servicio_id == servicio_id
        )
        result = await self.session.execute(stmt)
        asociacion = result.scalar_one_or_none()
        if asociacion:
            await self.session.delete(asociacion)
            await self.session.flush()
