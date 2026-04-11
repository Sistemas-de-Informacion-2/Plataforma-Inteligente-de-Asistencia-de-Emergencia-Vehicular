# backend/app/api/v1/endpoints/empleados.py
"""
Endpoints CRUD: Empleado (Técnico).
POST crea Usuario + Empleado en una sola transacción atómica.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user, get_current_admin
from app.models.usuario import Usuario
from app.schemas.empleado import (
    EmpleadoCreateFull,
    EmpleadoOut,
    EmpleadoUpdate,
    EmpleadoConUsuario,
)
from app.services.empleado_service import EmpleadoService

router = APIRouter()


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
    - Crea el Usuario base (hash_password, rol TECNICO) y luego
      el registro Empleado vinculado a la sucursal_id indicada.
    - Transacción atómica: si falla cualquier paso, se revierte todo.
    """
    service = EmpleadoService(db)
    try:
        return await service.crear_con_usuario(empleado_in)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ═══════════════════════════════════════════════════════════════
#  LISTAR EMPLEADOS
# ═══════════════════════════════════════════════════════════════

@router.get("/", response_model=list[EmpleadoConUsuario])
async def listar_empleados(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista todos los empleados (paginado)."""
    service = EmpleadoService(db)
    return await service.listar(skip=skip, limit=limit)


# ═══════════════════════════════════════════════════════════════
#  OBTENER EMPLEADO POR ID
# ═══════════════════════════════════════════════════════════════

@router.get("/{empleado_id}", response_model=EmpleadoOut)
async def obtener_empleado(
    empleado_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene el detalle de un empleado."""
    service = EmpleadoService(db)
    empleado = await service.obtener_por_id(empleado_id)
    if not empleado:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
    return empleado


# ═══════════════════════════════════════════════════════════════
#  ACTUALIZAR EMPLEADO
# ═══════════════════════════════════════════════════════════════

@router.patch("/{empleado_id}", response_model=EmpleadoOut)
async def actualizar_empleado(
    empleado_id: int,
    empleado_in: EmpleadoUpdate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza datos parciales de un empleado."""
    service = EmpleadoService(db)
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
    Solo un Admin autenticado puede ejecutar esta acción.
    """
    service = EmpleadoService(db)
    eliminado = await service.eliminar(empleado_id)
    if not eliminado:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
