# backend/app/api/v1/endpoints/pagos.py
"""
Endpoints para el sistema de pagos.
- Admin crea pago post-servicio
- Cliente paga con tarjeta (Stripe), efectivo o QR
- Verificación de deuda del admin
"""
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user, get_current_admin
from app.models.usuario import Usuario
from app.services.pago_service import PagoService

logger = logging.getLogger(__name__)
router = APIRouter()


# ── Schemas ──────────────────────────────────────────────────

class CrearPagoRequest(BaseModel):
    """Admin crea un pago después de atender el servicio."""
    solicitud_id: int
    monto_total: float = Field(..., gt=0, description="Monto total del servicio en Bs.")


class PagoResponse(BaseModel):
    pago_id: int
    orden_id: int
    monto_total: float
    comision: float
    monto_taller: float


class SeleccionMetodoRequest(BaseModel):
    """Cliente selecciona el método de pago."""
    tipo: str = Field(..., description="TARJETA, EFECTIVO o QR")


# ── Helper para obtener Admin desde Usuario ──────────────────

async def _get_admin_from_user(user: Usuario, db: AsyncSession):
    """Resuelve el modelo Admin a partir del usuario autenticado."""
    from sqlalchemy import select
    from app.models.admin import Admin
    stmt = select(Admin).where(Admin.usuario_id == user.id)
    result = await db.execute(stmt)
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=403, detail="No eres administrador de taller.")
    return admin


# ── Endpoints Admin ─────────────────────────────────────────

@router.post(
    "/",
    response_model=PagoResponse,
    summary="Crear pago post-servicio",
    description="El admin ingresa el monto del servicio después de atenderlo. Se calcula automáticamente la comisión del 10%.",
)
async def crear_pago(
    payload: CrearPagoRequest,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin = await _get_admin_from_user(current_user, db)
    service = PagoService(db)
    try:
        resultado = await service.crear_pago(
            solicitud_id=payload.solicitud_id,
            monto_total=payload.monto_total,
            admin_id=admin.id,
        )
        return PagoResponse(**resultado)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/{pago_id}/efectivo",
    summary="Confirmar cobro en efectivo",
    description="El admin confirma que cobró en efectivo. La comisión del 10% se añade a su deuda.",
)
async def confirmar_efectivo(
    pago_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin = await _get_admin_from_user(current_user, db)
    service = PagoService(db)
    exito = await service.marcar_pago_efectivo(pago_id, admin.id)
    if not exito:
        raise HTTPException(status_code=400, detail="No se pudo confirmar el pago en efectivo.")
    return {"message": "Pago en efectivo confirmado. Comisión añadida a la deuda."}


@router.get(
    "/deuda",
    summary="Consultar deuda de comisiones",
    description="El admin consulta su deuda acumulada por comisiones de pagos en efectivo.",
)
async def consultar_deuda(
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin = await _get_admin_from_user(current_user, db)
    from app.services.pago_service import LIMITE_DEUDA_BS
    return {
        "deuda_actual": admin.deuda_comision or 0,
        "limite": LIMITE_DEUDA_BS,
        "puede_aceptar_solicitudes": (admin.deuda_comision or 0) < LIMITE_DEUDA_BS,
    }


# ── Endpoints Cliente ────────────────────────────────────────

@router.post(
    "/{pago_id}/checkout",
    summary="Crear sesión de checkout Stripe",
    description="Genera una URL de Stripe Checkout para que el cliente pague con tarjeta.",
)
async def crear_checkout(
    pago_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = PagoService(db)
    try:
        url = await service.crear_checkout_stripe(pago_id)
        return {"checkout_url": url}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get(
    "/{pago_id}/exito",
    summary="Callback de éxito de Stripe",
)
async def pago_exitoso(
    pago_id: int,
    session_id: str,
    db: AsyncSession = Depends(get_db),
):
    service = PagoService(db)
    confirmado = await service.confirmar_pago_stripe(session_id)
    if confirmado:
        return {"message": "¡Pago completado exitosamente! Gracias por usar Fixo."}
    raise HTTPException(status_code=400, detail="No se pudo confirmar el pago.")


@router.get(
    "/{pago_id}/qr",
    summary="Obtener QR de pago",
    description="Retorna la URL del QR personalizado del taller, si existe.",
)
async def obtener_qr(
    pago_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = PagoService(db)
    try:
        qr_url = await service.obtener_qr_url(pago_id)
        if not qr_url:
             return {"qr_url": None, "message": "El taller no ha configurado un QR."}
        return {"qr_url": qr_url}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.post(
    "/{pago_id}/confirmar-qr",
    summary="Confirmar pago por QR",
    description="El cliente confirma que realizó el pago por QR. Se marca como completado y se suma deuda al admin.",
)
async def confirmar_pago_qr(
    pago_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = PagoService(db)
    exito = await service.confirmar_pago_qr(pago_id)
    if not exito:
        raise HTTPException(status_code=400, detail="No se pudo confirmar el pago QR.")
    return {"message": "Pago QR confirmado."}


@router.get(
    "/{pago_id}",
    summary="Obtener detalle de un pago",
)
async def obtener_pago(
    pago_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = PagoService(db)
    pago = await service.obtener_pago(pago_id)
    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado.")
    return {
        "id": pago.id,
        "monto_total": pago.monto_total,
        "comision": pago.comision,
        "monto_taller": pago.monto_taller,
        "estado": pago.estado.value,
        "tipo_pago": pago.tipo_pago.value if pago.tipo_pago else None,
        "fecha": pago.fecha.isoformat() if pago.fecha else None,
    }
