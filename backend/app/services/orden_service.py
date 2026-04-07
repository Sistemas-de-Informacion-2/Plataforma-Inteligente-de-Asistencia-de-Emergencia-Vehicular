"""
Servicio: Orden de Trabajo.
Gestión de órdenes y cálculo de pagos con comisión 10%.
"""

from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.orden_trabajo import OrdenTrabajo, EstadoOrden, DetalleOrden
from app.models.pago import Pago, EstadoPago
from app.repositories.orden_repository import OrdenRepository
from app.repositories.pago_repository import PagoRepository
from app.schemas.orden_trabajo import OrdenTrabajoCreate, OrdenTrabajoUpdate, DetalleOrdenCreate
from app.schemas.pago import PagoCreate


COMISION_PLATAFORMA = 0.10  # 10% comisión


class OrdenService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = OrdenRepository(session)
        self.pago_repo = PagoRepository(session)

    # ── Órdenes ───────────────────────────────────────────────

    async def crear(self, data: OrdenTrabajoCreate) -> OrdenTrabajo:
        return await self.repo.create(data.model_dump())

    async def obtener_por_id(self, orden_id: int) -> OrdenTrabajo | None:
        return await self.repo.get_by_id(orden_id)

    async def obtener_detallada(self, orden_id: int) -> OrdenTrabajo | None:
        return await self.repo.get_detallada(orden_id)

    async def listar_por_solicitud(self, solicitud_id: int) -> list[OrdenTrabajo]:
        return list(await self.repo.get_by_solicitud(solicitud_id))

    async def listar_por_sucursal(
        self,
        sucursal_id: int,
        estado: EstadoOrden | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> list[OrdenTrabajo]:
        return list(
            await self.repo.get_by_sucursal(
                sucursal_id, estado=estado, skip=skip, limit=limit
            )
        )

    async def actualizar_estado(
        self, orden_id: int, data: OrdenTrabajoUpdate
    ) -> OrdenTrabajo | None:
        update_data = data.model_dump(exclude_unset=True)

        # Si se marca como EN_PROGRESO, registrar fecha_inicio
        if update_data.get("estado") == EstadoOrden.EN_PROGRESO:
            update_data.setdefault("fecha_inicio", datetime.now(timezone.utc))

        # Si se marca como COMPLETADA, registrar fecha_fin
        if update_data.get("estado") == EstadoOrden.COMPLETADA:
            update_data.setdefault("fecha_fin", datetime.now(timezone.utc))

        return await self.repo.update(orden_id, update_data)

    # ── Detalles de orden ─────────────────────────────────────

    async def agregar_detalle(self, data: DetalleOrdenCreate) -> DetalleOrden:
        detalle = DetalleOrden(**data.model_dump())
        self.session.add(detalle)
        await self.session.flush()
        await self.session.refresh(detalle)
        return detalle

    # ── Pagos con comisión ────────────────────────────────────

    async def registrar_pago(self, data: PagoCreate) -> Pago:
        """
        Registra un pago calculando automáticamente:
        - comision = monto_total * 10%
        - monto_taller = monto_total * 90%
        """
        comision = round(data.monto_total * COMISION_PLATAFORMA, 2)
        monto_taller = round(data.monto_total - comision, 2)

        pago_data = data.model_dump()
        pago_data["comision"] = comision
        pago_data["monto_taller"] = monto_taller
        pago_data["estado"] = EstadoPago.PENDIENTE

        return await self.pago_repo.create(pago_data)

    async def obtener_pago_de_orden(self, orden_id: int) -> Pago | None:
        return await self.pago_repo.get_by_orden(orden_id)
