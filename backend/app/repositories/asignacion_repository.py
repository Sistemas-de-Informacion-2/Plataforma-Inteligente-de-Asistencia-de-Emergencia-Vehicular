# backend/app/repositories/asignacion_repository.py
"""
Repositorio: Asignacion.
Filtros por solicitud, empleado y estado.
"""
from typing import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.asignacion import Asignacion, EstadoAsignacion
from app.repositories.base import BaseRepository


class AsignacionRepository(BaseRepository[Asignacion]):
    def __init__(self, session: AsyncSession):
        super().__init__(Asignacion, session)

    async def get_by_solicitud(self, solicitud_id: int,) -> Sequence[Asignacion]:
        """Obtiene todas las asignaciones de una solicitud."""
        stmt = (
            select(Asignacion)
            .where(Asignacion.solicitud_id == solicitud_id)
            .order_by(Asignacion.fecha.desc())
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_by_empleado(
        self,
        empleado_id: int,
        *,
        estado: EstadoAsignacion | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Asignacion]:
        """Obtiene asignaciones de un empleado, opcionalmente por estado."""
        stmt = select(Asignacion).where(Asignacion.empleado_id == empleado_id)
        if estado:
            stmt = stmt.where(Asignacion.estado == estado)
        stmt = stmt.order_by(Asignacion.fecha.desc()).offset(skip).limit(limit)
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_historial_por_empleado(
        self,
        empleado_id: int,
        skip: int = 0,
        limit: int = 100,
    ) -> Sequence[Asignacion]:
        """Obtiene el historial de asignaciones de un empleado con detalles de solicitud."""
        from sqlalchemy.orm import selectinload
        from app.models.solicitud_emergencia import SolicitudEmergencia
        from app.models.taller import Sucursal
        from app.models.usuario import Usuario

        stmt = (
            select(Asignacion)
            .where(Asignacion.empleado_id == empleado_id)
            .options(
                selectinload(Asignacion.solicitud).selectinload(SolicitudEmergencia.vehiculo),
                selectinload(Asignacion.solicitud).selectinload(SolicitudEmergencia.cliente).selectinload(Usuario.perfil),
                selectinload(Asignacion.solicitud).selectinload(SolicitudEmergencia.diagnostico),
                selectinload(Asignacion.sucursal).selectinload(Sucursal.taller),
            )
            .order_by(Asignacion.fecha.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def get_activa_de_solicitud(self, solicitud_id: int, ) -> Asignacion | None:
        """Obtiene la asignación activa (no rechazada/completada) de una solicitud.
            Útil para saber si ya hay un técnico asignado."""
        stmt = (
            select(Asignacion)
            .where(
                Asignacion.solicitud_id == solicitud_id,
                Asignacion.estado.notin_([
                    EstadoAsignacion.RECHAZADA,
                    EstadoAsignacion.COMPLETADA,
                ]),
            )
            .order_by(Asignacion.fecha.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_activa_de_empleado(self, empleado_id: int, ) -> Asignacion | None:
        """ Obtiene la asignación activa (no rechazada/completada) de un empleado."""
        stmt = (
            select(Asignacion)
            .where(
                Asignacion.empleado_id == empleado_id,
                Asignacion.estado.notin_([
                    EstadoAsignacion.RECHAZADA,
                    EstadoAsignacion.COMPLETADA,
                ]),
            )
            .order_by(Asignacion.fecha.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def actualizar_estado(self, asignacion_id: int, nuevo_estado: EstadoAsignacion, ) -> Asignacion | None:
        """Actualiza el estado de una asignación."""
        return await self.update(asignacion_id, {"estado": nuevo_estado})
