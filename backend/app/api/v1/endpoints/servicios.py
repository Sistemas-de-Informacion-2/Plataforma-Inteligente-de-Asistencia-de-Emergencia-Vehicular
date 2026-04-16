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

#  CATÁLOGO GLOBAL DE SERVICIOS
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



