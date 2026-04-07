from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.taller import (
    TallerCreate, TallerOut, TallerConSucursales, TallerUpdate,
    SucursalCreate, SucursalOut, SucursalUpdate
)
from app.services.taller_service import TallerService, SucursalService

router = APIRouter()

# ═══════════════════════════════════════════════════════════════
#  TALLERES
# ═══════════════════════════════════════════════════════════════

@router.post("/", response_model=TallerOut, status_code=status.HTTP_201_CREATED)
async def crear_taller(
    taller_in: TallerCreate,
    db: AsyncSession = Depends(get_db)
):
    """Crea un nuevo taller."""
    service = TallerService(db)
    return await service.crear(taller_in)


@router.get("/", response_model=list[TallerOut])
async def listar_talleres(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """Lista todos los talleres."""
    service = TallerService(db)
    return await service.listar(skip=skip, limit=limit)


@router.get("/{taller_id}", response_model=TallerConSucursales)
async def obtener_taller(
    taller_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Obtiene un taller junto con sus sucursales."""
    service = TallerService(db)
    taller = await service.obtener_con_sucursales(taller_id)
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
    return taller


# ═══════════════════════════════════════════════════════════════
#  SUCURSALES
# ═══════════════════════════════════════════════════════════════

@router.post("/{taller_id}/sucursales", response_model=SucursalOut, status_code=status.HTTP_201_CREATED)
async def crear_sucursal(
    taller_id: int,
    sucursal_in: SucursalCreate,
    db: AsyncSession = Depends(get_db)
):
    """Crea una sucursal para un taller específico."""
    if taller_id != sucursal_in.taller_id:
        raise HTTPException(status_code=400, detail="El ID del taller no coincide")
        
    service = SucursalService(db)
    return await service.crear(sucursal_in)


@router.get("/{taller_id}/sucursales", response_model=list[SucursalOut])
async def listar_sucursales_de_taller(
    taller_id: int,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """Lista las sucursales de un taller."""
    service = SucursalService(db)
    return await service.listar_por_taller(taller_id, skip=skip, limit=limit)


@router.get("/sucursales/cercanas")
async def buscar_sucursales_cercanas(
    latitud: float,
    longitud: float,
    radio_km: float = 10.0,
    limit: int = 10,
    db: AsyncSession = Depends(get_db)
) -> list[dict[str, Any]]:
    """
    Busca sucursales mediante PostGIS ST_DWithin en un radio dado.
    Retorna la sucursal y su distancia en km.
    """
    service = SucursalService(db)
    resultados = await service.buscar_cercanas(latitud, longitud, radio_km, limit)
    
    # Adaptar para serializar con Pydantic
    return [
        {
            "sucursal": SucursalOut.model_validate(item["sucursal"]),
            "distancia_km": item["distancia_km"]
        }
        for item in resultados
    ]
