# backend/app/api/v1/endpoints/servicios.py
"""
Endpoints: Servicios (Catálogo global) y vinculación Sucursal ↔ Servicio.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user, get_current_admin
from app.models.usuario import Usuario
from app.models.servicio import Servicio, SucursalServicio
from app.models.taller import Sucursal
from app.schemas.servicio import (
    ServicioOut,
    SucursalServicioCreate,
    SucursalServicioOut,
)

router = APIRouter()


# ═══════════════════════════════════════════════════════════════
#  CATÁLOGO GLOBAL DE SERVICIOS
# ═══════════════════════════════════════════════════════════════

@router.get("/", response_model=list[ServicioOut])
async def listar_servicios(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista el catálogo global de servicios/especialidades."""
    stmt = select(Servicio).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


# ═══════════════════════════════════════════════════════════════
#  VINCULAR SERVICIO A SUCURSAL
# ═══════════════════════════════════════════════════════════════

@router.post(
    "/sucursales/{sucursal_id}/servicios",
    response_model=SucursalServicioOut,
    status_code=status.HTTP_201_CREATED,
)
async def asociar_servicio_a_sucursal(
    sucursal_id: int,
    servicio_in: SucursalServicioCreate,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Asocia un servicio existente a una sucursal.
    Solo un Admin autenticado puede ejecutar esta acción.
    """
    # Validar que la sucursal existe
    sucursal = await db.get(Sucursal, sucursal_id)
    if not sucursal:
        raise HTTPException(status_code=404, detail="Sucursal no encontrada")

    # Validar que el servicio existe
    servicio = await db.get(Servicio, servicio_in.servicio_id)
    if not servicio:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")

    # Verificar que no exista ya la asociación
    stmt = select(SucursalServicio).where(
        SucursalServicio.sucursal_id == sucursal_id,
        SucursalServicio.servicio_id == servicio_in.servicio_id,
    )
    result = await db.execute(stmt)
    existente = result.scalar_one_or_none()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Este servicio ya está asociado a la sucursal",
        )

    # Crear la asociación
    vinculo = SucursalServicio(
        sucursal_id=sucursal_id,
        servicio_id=servicio_in.servicio_id,
    )
    db.add(vinculo)
    await db.flush()
    await db.refresh(vinculo)

    return vinculo
