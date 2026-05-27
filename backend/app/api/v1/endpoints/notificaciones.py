# backend/app/api/v1/endpoints/notificaciones.py
"""
Endpoints: Notificaciones.

GET  /api/v1/notificaciones/             → Lista las notificaciones del usuario autenticado.
GET  /api/v1/notificaciones/no-leidas/contar → Cuenta las notificaciones no leídas del usuario.
PUT  /api/v1/notificaciones/{id}/leer     → Marca una notificación específica como leída.
PUT  /api/v1/notificaciones/leer-todas    → Marca todas las notificaciones como leídas.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.usuario import Usuario
from app.schemas.notificacion import NotificacionOut
from app.services.notificacion_service import NotificacionService

router = APIRouter()


@router.get(
    "/",
    response_model=List[NotificacionOut],
    summary="Listar notificaciones del usuario autenticado",
    description="Retorna el historial de notificaciones del usuario actual, ordenado por fecha descendente.",
)
async def listar_notificaciones(
    solo_no_leidas: bool = False,
    skip: int = 0,
    limit: int = 50,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificacionService(db)
    notificaciones = await service.listar_por_usuario(
        usuario_id=current_user.id,
        solo_no_leidas=solo_no_leidas,
        skip=skip,
        limit=limit,
    )
    return notificaciones


@router.get(
    "/no-leidas/contar",
    summary="Contar notificaciones no leídas",
    description="Retorna la cantidad de notificaciones que el usuario actual no ha leído.",
)
async def contar_no_leidas(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificacionService(db)
    cantidad = await service.contar_no_leidas(current_user.id)
    return {"usuario_id": current_user.id, "no_leidas_count": cantidad}


@router.put(
    "/{notificacion_id}/leer",
    response_model=NotificacionOut,
    summary="Marcar notificación como leída",
    description="Marca una notificación específica del usuario actual como leída.",
)
async def marcar_como_leida(
    notificacion_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificacionService(db)
    
    # Obtener primero para validar pertenencia
    notificacion = await db.get(service.repo.model, notificacion_id)
    if not notificacion:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Notificación #{notificacion_id} no encontrada."
        )
    
    if notificacion.usuario_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para modificar esta notificación."
        )
        
    resultado = await service.marcar_como_leida(notificacion_id)
    return resultado


@router.put(
    "/leer-todas",
    summary="Marcar todas las notificaciones como leídas",
    description="Marca de forma masiva todas las notificaciones del usuario actual como leídas.",
)
async def marcar_todas_leidas(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificacionService(db)
    actualizadas = await service.marcar_todas_leidas(current_user.id)
    return {
        "message": f"Se marcaron {actualizadas} notificaciones como leídas.",
        "actualizadas": actualizadas,
    }
