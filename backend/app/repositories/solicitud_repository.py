# backend/app/repositories/solicitud_repository.py
"""
Repositorio: SolicitudEmergencia.
Filtros por estado y cliente.
"""
from typing import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.solicitud_emergencia import SolicitudEmergencia, EstadoSolicitud
from app.repositories.base import BaseRepository

class SolicitudRepository(BaseRepository[SolicitudEmergencia]):
    def __init__(self, session: AsyncSession):
        super().__init__(SolicitudEmergencia, session)

    async def get_by_cliente(
        self,
        cliente_id: int,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[SolicitudEmergencia]:
        """Obtiene todas las solicitudes de un cliente."""
        stmt = (
            select(SolicitudEmergencia)
            .where(
                SolicitudEmergencia.cliente_id == cliente_id,
                SolicitudEmergencia.es_eliminado == False
            )
            .order_by(SolicitudEmergencia.fecha_creacion.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_activa_por_cliente(self, cliente_id: int) -> SolicitudEmergencia | None:
        """Obtiene la solicitud activa más reciente de un cliente."""
        stmt = (
            select(SolicitudEmergencia)
            .where(
                SolicitudEmergencia.cliente_id == cliente_id,
                SolicitudEmergencia.es_eliminado == False,
                SolicitudEmergencia.estado.in_([
                    EstadoSolicitud.PENDIENTE,
                    EstadoSolicitud.ESPERANDO_PUJAS,
                    EstadoSolicitud.OFERTA_ACEPTADA,
                    EstadoSolicitud.ESPERANDO_CONFIRMACION_MECANICO,
                    EstadoSolicitud.EN_CAMINO,
                    EstadoSolicitud.EN_SITIO,
                ])
            )
            .order_by(SolicitudEmergencia.fecha_creacion.desc())
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def get_by_estado(
        self,
        estado: EstadoSolicitud,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[SolicitudEmergencia]:
        """Obtiene solicitudes filtradas por estado."""
        stmt = (
            select(SolicitudEmergencia)
            .where(
                SolicitudEmergencia.estado == estado,
                SolicitudEmergencia.es_eliminado == False
            )
            .order_by(SolicitudEmergencia.fecha_creacion.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_pendientes(
        self,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[SolicitudEmergencia]:
        """Atajo: obtiene solicitudes pendientes (las que los talleres ven)."""
        return await self.get_by_estado(
            EstadoSolicitud.PENDIENTE, skip=skip, limit=limit
        )

    async def get_detallada(self, solicitud_id: int) -> SolicitudEmergencia | None:
        """
        Obtiene una solicitud con evidencias y diagnóstico IA precargados.
        Ideal para la vista detallada del taller.
        """
        stmt = (
            select(SolicitudEmergencia)
            .options(
                selectinload(SolicitudEmergencia.evidencias),
                selectinload(SolicitudEmergencia.diagnostico),
                selectinload(SolicitudEmergencia.vehiculo),
                selectinload(SolicitudEmergencia.asignaciones),
            )
            .where(
                SolicitudEmergencia.id == solicitud_id,
                SolicitudEmergencia.es_eliminado == False
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_detalladas_por_estado(
        self,
        estado: EstadoSolicitud,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[SolicitudEmergencia]:
        """Solicitudes filtradas por estado CON evidencias y diagnóstico precargados."""
        stmt = (
            select(SolicitudEmergencia)
            .options(
                selectinload(SolicitudEmergencia.evidencias),
                selectinload(SolicitudEmergencia.diagnostico),
                selectinload(SolicitudEmergencia.vehiculo),
                selectinload(SolicitudEmergencia.asignaciones),
            )
            .where(
                SolicitudEmergencia.estado == estado,
                SolicitudEmergencia.es_eliminado == False
            )
            .order_by(SolicitudEmergencia.fecha_creacion.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_detalladas_por_sucursal_y_estado(
        self,
        sucursal_id: int,
        estado: EstadoSolicitud,
        *,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[SolicitudEmergencia]:
        """Filtra por sucursal (mediante asignacion) y estado."""
        from app.models.asignacion import Asignacion
        stmt = (
            select(SolicitudEmergencia)
            .join(Asignacion, Asignacion.solicitud_id == SolicitudEmergencia.id)
            .options(
                selectinload(SolicitudEmergencia.evidencias),
                selectinload(SolicitudEmergencia.diagnostico),
                selectinload(SolicitudEmergencia.vehiculo),
                selectinload(SolicitudEmergencia.asignaciones)
            )
            .where(
                SolicitudEmergencia.estado == estado,
                SolicitudEmergencia.es_eliminado == False,
                Asignacion.sucursal_id == sucursal_id
            )
            .order_by(SolicitudEmergencia.fecha_creacion.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def actualizar_estado(
        self,
        solicitud_id: int,
        nuevo_estado: EstadoSolicitud,
    ) -> SolicitudEmergencia | None:
        """Actualiza el estado de una solicitud."""
        return await self.update(solicitud_id, {"estado": nuevo_estado})
