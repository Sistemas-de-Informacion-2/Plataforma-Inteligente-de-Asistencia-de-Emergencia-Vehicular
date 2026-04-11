# backend/app/api/v1/endpoints/empleados.py
"""
Endpoints CRUD: Empleado (Técnico).
POST crea Usuario + Empleado en una sola transacción atómica.
SEGURIDAD: Todos los endpoints verifican que el recurso pertenezca
al taller del Admin autenticado (Tenant Isolation).
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user, get_current_admin
from app.models.usuario import Usuario
from app.models.admin import Admin
from app.schemas.empleado import (
    EmpleadoCreateFull,
    EmpleadoOut,
    EmpleadoUpdate,
    EmpleadoConUsuario,
)
from app.services.empleado_service import EmpleadoService
from app.repositories.taller_repository import TallerRepository

router = APIRouter()


# ── Utilidad interna: obtener admin_id del usuario actual ────────────────────

async def _get_admin_id(current_user: Usuario, db: AsyncSession) -> int:
    """
    Extrae el admin_id asociado al usuario autenticado.
    Lanza 403 si el usuario no tiene perfil de Admin.
    """
    stmt = select(Admin).where(Admin.usuario_id == current_user.id)
    result = await db.execute(stmt)
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes un perfil de Administrador de Taller.",
        )
    return admin.id


# ═══════════════════════════════════════════════════════════════
#  CREAR EMPLEADO (Usuario + Rol TECNICO + Empleado)
# ═══════════════════════════════════════════════════════════════

@router.post("/", response_model=EmpleadoOut, status_code=status.HTTP_201_CREATED)
async def crear_empleado(
    empleado_in: EmpleadoCreateFull,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Crea un nuevo técnico (empleado).
    - Solo un Admin autenticado puede ejecutar esta acción.
    - SEGURIDAD: Verifica que la sucursal_id pertenezca al taller del admin.
      Si intenta asignar el técnico a una sucursal ajena, retorna 403.
    - Transacción atómica: si falla cualquier paso, se revierte todo.
    """
    admin_id = await _get_admin_id(current_user, db)

    # ── Verificar ownership de la sucursal ────────────────────
    taller_repo = TallerRepository(db)
    sucursales_propias = await taller_repo.get_sucursal_ids_by_admin(admin_id)
    if empleado_in.sucursal_id not in sucursales_propias:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="La sucursal indicada no pertenece a ninguno de tus talleres.",
        )

    service = EmpleadoService(db)
    try:
        return await service.crear_con_usuario(empleado_in)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ═══════════════════════════════════════════════════════════════
#  LISTAR EMPLEADOS (Scoped al taller del admin)
# ═══════════════════════════════════════════════════════════════

@router.get("/", response_model=list[EmpleadoConUsuario])
async def listar_empleados(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Lista los empleados del taller del Admin autenticado.
    NUNCA retorna empleados de otros talleres.
    """
    admin_id = await _get_admin_id(current_user, db)
    service = EmpleadoService(db)
    return await service.listar_por_admin(admin_id, skip=skip, limit=limit)


# ═══════════════════════════════════════════════════════════════
#  OBTENER EMPLEADO POR ID
# ═══════════════════════════════════════════════════════════════

@router.get("/{empleado_id}", response_model=EmpleadoConUsuario)
async def obtener_empleado(
    empleado_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Obtiene el detalle de un empleado.
    SEGURIDAD: Retorna 404 si el empleado no le pertenece al admin.
    """
    admin_id = await _get_admin_id(current_user, db)
    service = EmpleadoService(db)
    empleado = await service.obtener_por_id_scoped(empleado_id, admin_id)
    if not empleado:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Empleado no encontrado o no pertenece a tu taller.",
        )
    return empleado


# ═══════════════════════════════════════════════════════════════
#  ACTUALIZAR EMPLEADO
# ═══════════════════════════════════════════════════════════════

@router.patch("/{empleado_id}", response_model=EmpleadoOut)
async def actualizar_empleado(
    empleado_id: int,
    empleado_in: EmpleadoUpdate,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Actualiza datos parciales de un empleado.
    SEGURIDAD:
    - Verifica que el empleado sea del taller del admin antes de editar.
    - Si se cambia sucursal_id, verifica que la nueva sucursal también
      pertenezca al admin (no permite mover a la competencia).
    """
    admin_id = await _get_admin_id(current_user, db)
    service = EmpleadoService(db)

    # Verificar que el empleado le pertenece al admin
    empleado_existente = await service.obtener_por_id_scoped(empleado_id, admin_id)
    if not empleado_existente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Empleado no encontrado o no pertenece a tu taller.",
        )

    # Si intenta reasignar a otra sucursal, verificar que esa sucursal también es suya
    if empleado_in.sucursal_id is not None:
        taller_repo = TallerRepository(db)
        sucursales_propias = await taller_repo.get_sucursal_ids_by_admin(admin_id)
        if empleado_in.sucursal_id not in sucursales_propias:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="La sucursal de destino no pertenece a ninguno de tus talleres.",
            )

    empleado = await service.actualizar(empleado_id, empleado_in)
    if not empleado:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
    return empleado


# ═══════════════════════════════════════════════════════════════
#  ELIMINAR EMPLEADO (Soft Delete)
# ═══════════════════════════════════════════════════════════════

@router.delete("/{empleado_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_empleado(
    empleado_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Elimina (soft delete) un empleado.
    SEGURIDAD: Solo puede eliminar empleados de su propio taller.
    """
    admin_id = await _get_admin_id(current_user, db)
    service = EmpleadoService(db)

    # Verificar ownership antes de eliminar
    empleado = await service.obtener_por_id_scoped(empleado_id, admin_id)
    if not empleado:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Empleado no encontrado o no pertenece a tu taller.",
        )

    eliminado = await service.eliminar(empleado_id)
    if not eliminado:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
