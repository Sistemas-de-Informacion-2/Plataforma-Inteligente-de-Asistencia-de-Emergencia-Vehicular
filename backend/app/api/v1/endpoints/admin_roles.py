# backend/app/api/v1/endpoints/admin_roles.py
"""
Endpoints de Gestión de Roles y Permisos para el Super Admin.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.api.deps import get_current_super_admin
from app.models.usuario import Usuario
from app.schemas.rol import RolCreate, RolUpdate, RolConPermisos, PermisoOut
from app.repositories.rol_repository import RolRepository, PermisoRepository

router = APIRouter()

# ── PERMISOS ───────────────────────────────────────────────────

@router.get("/permisos/", response_model=list[PermisoOut])
async def listar_permisos(
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista todos los permisos estáticos disponibles en el sistema."""
    repo = PermisoRepository(db)
    return await repo.get_all_permisos()


# ── ROLES ──────────────────────────────────────────────────────

@router.get("/", response_model=list[RolConPermisos])
async def listar_roles(
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista todos los roles con sus respectivos permisos asignados."""
    repo = RolRepository(db)
    roles = await repo.get_all_roles()
    
    # Formateamos para que retorne los permisos correctamente.
    # sqlalchemy carga RolPermiso, necesitamos extraer el Permiso.
    # El esquema RolConPermisos espera una lista de PermisoOut.
    # Pydantic puede requerir que transformemos la relación manualmente si usamos from_attributes,
    # pero como tenemos Rol.permisos que apunta a RolPermiso, necesitamos extraer permiso.
    
    # Transformación manual para coincidir con el schema RolConPermisos
    resultado = []
    for rol in roles:
        rol_dict = {
            "id": rol.id,
            "nombre": rol.nombre,
            "permisos": [rp.permiso for rp in rol.permisos]
        }
        resultado.append(rol_dict)
        
    return resultado


@router.post("/", response_model=RolConPermisos, status_code=status.HTTP_201_CREATED)
async def crear_rol(
    rol_in: RolCreate,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Crea un nuevo rol y le asigna los permisos indicados."""
    repo = RolRepository(db)
    
    existente = await repo.get_rol_by_nombre(rol_in.nombre)
    if existente:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ya existe un rol con el nombre '{rol_in.nombre}'",
        )
        
    rol = await repo.create_rol(nombre=rol_in.nombre, permisos_ids=rol_in.permisos_ids)
    return {
        "id": rol.id,
        "nombre": rol.nombre,
        "permisos": [rp.permiso for rp in rol.permisos]
    }


@router.put("/{rol_id}", response_model=RolConPermisos)
async def actualizar_rol(
    rol_id: int,
    rol_in: RolUpdate,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza el nombre de un rol y/o sus permisos asignados."""
    repo = RolRepository(db)
    
    rol_existente = await repo.get_rol_by_id(rol_id)
    if not rol_existente:
        raise HTTPException(status_code=404, detail="Rol no encontrado")
        
    if rol_in.nombre and rol_in.nombre != rol_existente.nombre:
        conflicto = await repo.get_rol_by_nombre(rol_in.nombre)
        if conflicto:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe un rol con el nombre '{rol_in.nombre}'",
            )
            
    rol = await repo.update_rol(
        rol_id=rol_id, 
        nombre=rol_in.nombre, 
        permisos_ids=rol_in.permisos_ids
    )
    
    return {
        "id": rol.id,
        "nombre": rol.nombre,
        "permisos": [rp.permiso for rp in rol.permisos]
    }


@router.delete("/{rol_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_rol(
    rol_id: int,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Elimina un rol de forma definitiva."""
    repo = RolRepository(db)
    
    # Podrías agregar validación para no eliminar roles del sistema como 'SUPER_ADMIN'
    rol = await repo.get_rol_by_id(rol_id)
    if not rol:
        raise HTTPException(status_code=404, detail="Rol no encontrado")
        
    if rol.nombre in ["SUPER_ADMIN", "ADMIN_TALLER", "MECANICO", "CLIENTE"]:
        raise HTTPException(status_code=403, detail="No se pueden eliminar los roles del sistema.")
        
    await repo.delete_rol(rol_id)
