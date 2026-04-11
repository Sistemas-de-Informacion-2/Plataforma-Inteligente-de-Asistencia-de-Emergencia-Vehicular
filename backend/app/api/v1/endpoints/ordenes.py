# backend/app/api/v1/endpoints/ordenes.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.orden_trabajo import EstadoOrden
from app.schemas.orden_trabajo import (
    OrdenTrabajoCreate, OrdenTrabajoOut, OrdenTrabajoUpdate, 
    OrdenTrabajoDetallada, DetalleOrdenCreate, DetalleOrdenOut
)
from app.schemas.pago import PagoCreate, PagoOut
from app.services.orden_service import OrdenService

router = APIRouter()


@router.post("/", response_model=OrdenTrabajoOut, status_code=status.HTTP_201_CREATED)
async def crear_orden(
    orden_in: OrdenTrabajoCreate,
    db: AsyncSession = Depends(get_db)
):
    """Crea una orden de trabajo para una solicitud."""
    service = OrdenService(db)
    return await service.crear(orden_in)


@router.get("/{orden_id}", response_model=OrdenTrabajoDetallada)
async def obtener_orden_detallada(
    orden_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Obtiene una orden de trabajo, sus ítems y pago anidado."""
    service = OrdenService(db)
    orden = await service.obtener_detallada(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    return orden


@router.patch("/{orden_id}/estado", response_model=OrdenTrabajoOut)
async def actualizar_estado_orden(
    orden_id: int,
    estado: EstadoOrden,
    db: AsyncSession = Depends(get_db)
):
    """Actualiza el estado de la orden (auto-registra fechas de inicio/fin)."""
    service = OrdenService(db)
    update_data = OrdenTrabajoUpdate(estado=estado)
    orden = await service.actualizar_estado(orden_id, update_data)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    return orden


@router.post("/{orden_id}/detalles", response_model=DetalleOrdenOut, status_code=status.HTTP_201_CREATED)
async def agregar_detalle_a_orden(
    orden_id: int,
    detalle_in: DetalleOrdenCreate,
    db: AsyncSession = Depends(get_db)
):
    """Agrega un ítem detallado a la orden (repuestos, mano de obra, etc)."""
    if orden_id != detalle_in.orden_id:
        raise HTTPException(status_code=400, detail="El ID de la orden no coincide")
        
    service = OrdenService(db)
    return await service.agregar_detalle(detalle_in)


@router.post("/{orden_id}/pagos", response_model=PagoOut, status_code=status.HTTP_201_CREATED)
async def registrar_pago(
    orden_id: int,
    pago_in: PagoCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Registra el pago de una orden.
    El sistema descontará el 10% automáticamente como comisión de plataforma.
    """
    if orden_id != pago_in.orden_id:
        raise HTTPException(status_code=400, detail="El ID de la orden no coincide")
        
    service = OrdenService(db)
    return await service.registrar_pago(pago_in)
