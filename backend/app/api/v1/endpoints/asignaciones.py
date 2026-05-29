# backend/app/api/v1/endpoints/asignaciones.py
"""
Endpoints: Flujo de Ejecución del Mecánico.

POST /api/v1/asignaciones/{id}/respuesta  → Aceptar o rechazar asignación.
POST /api/v1/asignaciones/{id}/llegada    → Marcar 'Ya llegué'.
POST /api/v1/asignaciones/{id}/finalizar  → Finalizar el trabajo.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_tecnico_o_admin
from app.models.usuario import Usuario
from app.schemas.asignacion import MecanicoRespuestaCreate, AsignacionOut
from app.services.solicitud_service import SolicitudService

router = APIRouter()


@router.post(
    "/{asignacion_id}/respuesta",
    response_model=AsignacionOut,
    summary="Mecánico acepta o rechaza una asignación",
    description=(
        "El mecánico responde a su asignación. Si acepta, la solicitud pasa "
        "a EN_CAMINO y el cliente es notificado. Si rechaza, se guarda el motivo "
        "y el admin es notificado para reasignar."
    ),
)
async def responder_asignacion(
    asignacion_id: int,
    body: MecanicoRespuestaCreate,
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint protegido por JWT (rol MECANICO o ADMIN_TALLER).
    Valida que la asignación pertenezca al técnico autenticado o al Admin dueño.
    """
    service = SolicitudService(db)

    try:
        asignacion = await service.responder_asignacion_mecanico(
            asignacion_id=asignacion_id,
            usuario_id=current_user.id,
            aceptar=body.aceptar,
            motivo_rechazo=body.motivo_rechazo,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return asignacion


@router.post(
    "/{asignacion_id}/llegada",
    response_model=AsignacionOut,
    summary="Mecánico marca que llegó al sitio",
    description=(
        "El mecánico presiona 'Ya llegué'. La solicitud pasa a EN_SITIO "
        "y el cliente es notificado en tiempo real."
    ),
)
async def marcar_llegada(
    asignacion_id: int,
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Cambia el estado de la asignación y la solicitud a EN_SITIO.
    """
    service = SolicitudService(db)

    try:
        asignacion = await service.marcar_llegada(
            asignacion_id=asignacion_id,
            usuario_id=current_user.id,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return asignacion


@router.post(
    "/{asignacion_id}/finalizar",
    response_model=AsignacionOut,
    summary="Finalizar el trabajo de emergencia",
    description=(
        "El mecánico o admin finaliza el servicio. La solicitud pasa a FINALIZADO "
        "y el cliente es notificado para proceder al pago."
    ),
)
async def finalizar_trabajo(
    asignacion_id: int,
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Cambia la asignación a COMPLETADA y la solicitud a FINALIZADO.
    Prepara el terreno para el módulo de pagos.
    """
    service = SolicitudService(db)

    try:
        asignacion = await service.finalizar_trabajo(
            asignacion_id=asignacion_id,
            usuario_id=current_user.id,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return asignacion
