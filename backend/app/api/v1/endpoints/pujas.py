# backend/app/api/v1/endpoints/pujas.py
"""
Endpoints: Marketplace de Pujas (inDrive).

POST /api/v1/pujas/           → El taller envía su oferta (solo precio).
GET  /api/v1/pujas/{solicitud_id} → Lista pujas de una solicitud (reconexión).
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_admin, get_current_user
from app.models.usuario import Usuario
from app.models.admin import Admin
from app.models.taller import Taller, Sucursal
from app.schemas.puja import PujaCreate, PujaOut
from app.services.puja_service import PujaService

router = APIRouter()


async def _resolver_sucursal_del_admin(
    current_user: Usuario,
    db: AsyncSession,
) -> int:
    """
    Resuelve la sucursal principal del admin autenticado.
    Asume que el admin tiene al menos un taller con una sucursal.
    Si tiene múltiples sucursales, toma la primera.
    """
    stmt = (
        select(Sucursal.id)
        .join(Taller, Sucursal.taller_id == Taller.id)
        .join(Admin, Taller.admin_id == Admin.id)
        .where(Admin.usuario_id == current_user.id)
        .limit(1)
    )
    result = await db.execute(stmt)
    sucursal_id = result.scalar_one_or_none()

    if not sucursal_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes una sucursal asociada para enviar pujas."
        )
    return sucursal_id


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    summary="Enviar una puja (oferta de precio)",
    description=(
        "El taller envía solo el precio estimado. El backend calcula el ETA "
        "con PostGIS y reenvía la puja al cliente vía WebSocket en tiempo real."
    ),
)
async def crear_puja(
    puja_in: PujaCreate,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint para que un taller puje por una emergencia.
    El admin autenticado se mapea a su sucursal automáticamente.
    """
    # Resolver sucursal del admin autenticado
    sucursal_id = await _resolver_sucursal_del_admin(current_user, db)

    service = PujaService(db)

    try:
        resultado = await service.crear_puja(
            solicitud_id=puja_in.solicitud_id,
            sucursal_id=sucursal_id,
            precio_estimado=puja_in.precio_estimado,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    puja = resultado["puja"]

    return {
        "message": "Puja enviada exitosamente. El cliente ha sido notificado en tiempo real.",
        "puja": {
            "id": puja.id,
            "solicitud_id": puja.solicitud_id,
            "sucursal_id": puja.sucursal_id,
            "precio_estimado": puja.precio_estimado,
            "tiempo_llegada_minutos": puja.tiempo_llegada_minutos,
            "estado": puja.estado.value,
            "fecha": puja.fecha.isoformat(),
        },
        "datos_enriquecidos": {
            "sucursal_nombre": resultado["sucursal_nombre"],
            "taller_nombre": resultado["taller_nombre"],
            "rating": resultado["rating"],
            "rating_count": resultado["rating_count"],
            "distancia_km": resultado["distancia_km"],
        },
    }


@router.get(
    "/{solicitud_id}",
    summary="Listar pujas de una solicitud",
    description=(
        "Retorna todas las pujas de una solicitud con datos enriquecidos. "
        "Usado para reconexión del cliente o carga inicial."
    ),
)
async def listar_pujas(
    solicitud_id: int,
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint para obtener las pujas existentes de una solicitud.
    Útil si el cliente se desconecta y reconecta — recupera el estado actual.
    """
    service = PujaService(db)
    pujas = await service.listar_pujas_solicitud(solicitud_id)
    return {
        "solicitud_id": solicitud_id,
        "total_pujas": len(pujas),
        "pujas": pujas,
    }


@router.post(
    "/{puja_id}/rechazar",
    summary="El cliente rechaza una puja",
    description=(
        "El cliente marca una puja individual como rechazada (por acción "
        "manual o timeout). Esto notifica al taller para que intente con "
        "una oferta mejor."
    ),
)
async def rechazar_puja(
    puja_id: int,
    current_user: Usuario = Depends(get_current_user), # Cliente autenticado
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint para que el cliente rechace una puja explícitamente.
    """
    service = PujaService(db)
    try:
        await service.rechazar_puja_cliente(
            puja_id=puja_id,
            current_user_id=current_user.id,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return {"message": "Puja rechazada exitosamente. Se ha notificado al taller."}


@router.post(
    "/{puja_id}/aceptar",
    summary="El cliente acepta una puja (Match Final)",
    description=(
        "El cliente selecciona la oferta ganadora. Se rechazan automáticamente "
        "las demás pujas, se crea la asignación y se notifica al taller ganador "
        "para que asigne un mecánico."
    ),
)
async def aceptar_puja(
    puja_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Match Final: el cliente elige la puja ganadora.
    Solicitud pasa a OFERTA_ACEPTADA. El admin deberá asignar un mecánico.
    """
    service = PujaService(db)

    # Obtener la puja para extraer solicitud_id
    from app.repositories.puja_repository import PujaRepository
    puja_repo = PujaRepository(db)
    puja = await puja_repo.get_by_id(puja_id)
    if not puja:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Puja #{puja_id} no encontrada.",
        )

    try:
        resultado = await service.seleccionar_puja(
            solicitud_id=puja.solicitud_id,
            puja_id=puja_id,
            current_user_id=current_user.id,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return {
        "message": "Oferta aceptada exitosamente. El taller ha sido notificado para asignar un mecánico.",
        **resultado,
    }
