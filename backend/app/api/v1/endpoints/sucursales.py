# backend/app/api/v1/endpoints/sucursales.py
"""
Endpoints: Gestión dedicada de Sucursales (Relaciones N:M).
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.api.deps import get_current_admin
from app.models.usuario import Usuario
from app.models.admin import Admin
from app.schemas.servicio import SucursalServicioOut
from app.services.taller_service import SucursalService

router = APIRouter()

async def obtener_admin_id(current_user: Usuario, db: AsyncSession) -> int:
    stmt = select(Admin).where(Admin.usuario_id == current_user.id)
    result = await db.execute(stmt)
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes un perfil de Admin asociado."
        )
    return admin.id

@router.get("/{sucursal_id}/servicios", response_model=list[SucursalServicioOut])
async def listar_servicios_asignados(
    sucursal_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista los servicios asignados a una sucursal específica."""
    # Nota: También podríamos verificar pertenencia aquí, pero como es lectura podemos dejarlo libre al admin si se desea.
    # Por consistencia, verificamos pertenencia.
    admin_id = await obtener_admin_id(current_user, db)
    service = SucursalService(db)
    
    # Check simple si le pertenece (opcional para lectura, pero recomendado)
    from app.repositories.taller_repository import TallerRepository
    taller_repo = TallerRepository(db)
    sucursales_propias = await taller_repo.get_sucursal_ids_by_admin(admin_id)
    if sucursal_id not in sucursales_propias:
        raise HTTPException(status_code=403, detail="Esta sucursal no te pertenece")
        
    return await service.obtener_servicios_asignados(sucursal_id)


@router.post(
    "/{sucursal_id}/servicios/{servicio_id}",
    status_code=status.HTTP_201_CREATED,
)
async def asignar_servicio_a_sucursal(
    sucursal_id: int,
    servicio_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Asigna un servicio del catálogo maestro a la sucursal."""
    admin_id = await obtener_admin_id(current_user, db)
    service = SucursalService(db)
    try:
        await service.asignar_servicio(sucursal_id, servicio_id, admin_id)
        return {"mensaje": "Servicio asignado correctamente"}
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        # En caso de Foreign Key violation u otros
        raise HTTPException(status_code=400, detail="Servicio o sucursal no válidos")


@router.delete(
    "/{sucursal_id}/servicios/{servicio_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def quitar_servicio_de_sucursal(
    sucursal_id: int,
    servicio_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Quita un servicio asignado de la sucursal."""
    admin_id = await obtener_admin_id(current_user, db)
    service = SucursalService(db)
    try:
        await service.quitar_servicio(sucursal_id, servicio_id, admin_id)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))
    return None
