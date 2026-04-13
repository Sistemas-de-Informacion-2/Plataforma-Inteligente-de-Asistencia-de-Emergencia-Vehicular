from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.api.deps import get_current_user
from app.schemas.vehiculo import VehiculoCreate, VehiculoOut, VehiculoBase, VehiculoUpdate
from app.models.vehiculo import Vehiculo
from app.repositories.vehiculo_repository import VehiculoRepository

router = APIRouter()

@router.post("/", response_model=VehiculoOut, status_code=status.HTTP_201_CREATED)
async def crear_vehiculo(
    vehiculo_in: VehiculoBase,  # El usuario no debe enviar su propio ID
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Crea un nuevo vehículo asociado al usuario logueado."""
    vehiculo_data = vehiculo_in.model_dump()
    vehiculo_data["usuario_id"] = current_user.id
    
    nuevo_vehiculo = Vehiculo(**vehiculo_data)
    db.add(nuevo_vehiculo)
    
    try:
        await db.commit()
        await db.refresh(nuevo_vehiculo)
        return nuevo_vehiculo
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Error al registrar vehículo")


@router.get("/", response_model=list[VehiculoOut])
async def obtener_mis_vehiculos(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Obtiene los vehículos del usuario actual."""
    stmt = select(Vehiculo).where(
        Vehiculo.usuario_id == current_user.id,
        Vehiculo.es_eliminado == False
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.patch("/{vehiculo_id}", response_model=VehiculoOut)
async def actualizar_vehiculo(
    vehiculo_id: int,
    vehiculo_in: VehiculoUpdate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Actualiza datos de un vehículo perteneciente al usuario actual."""
    # Verificar existencia y propiedad
    stmt = select(Vehiculo).where(Vehiculo.id == vehiculo_id, Vehiculo.usuario_id == current_user.id)
    result = await db.execute(stmt)
    vehiculo = result.scalar_one_or_none()
    
    if not vehiculo:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado o no autorizado")

    update_data = vehiculo_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(vehiculo, field, value)

    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo


@router.delete("/{vehiculo_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_vehiculo(
    vehiculo_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Elimina lógicamente un vehículo perteneciente al usuario."""
    repo = VehiculoRepository(db)
    
    # Check ownership
    stmt = select(Vehiculo).where(Vehiculo.id == vehiculo_id, Vehiculo.usuario_id == current_user.id)
    result = await db.execute(stmt)
    vehiculo = result.scalar_one_or_none()
    
    if not vehiculo:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado o no autorizado")

    try:
        await repo.delete(vehiculo_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail="Error al eliminar vehículo.")
    
    return None
