# backend/app/api/v1/endpoints/usuarios.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user
from app.schemas.usuario import UsuarioCreate, UsuarioOut, UsuarioUpdate, UsuarioConRoles, UsuarioPerfilCompletoUpdate
from app.services.usuario_service import UsuarioService

router = APIRouter()


@router.post("/", response_model=UsuarioOut, status_code=status.HTTP_201_CREATED)
async def registrar_usuario(
    usuario_in: UsuarioCreate,
    db: AsyncSession = Depends(get_db)
):
    """Registra un nuevo usuario en el sistema."""
    service = UsuarioService(db)
    try:
        return await service.registrar(usuario_in)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/", response_model=list[UsuarioOut])
async def listar_usuarios(
    skip: int = 0, 
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """Obtiene el listado paginado de usuarios."""
    service = UsuarioService(db)
    return await service.listar(skip=skip, limit=limit)


@router.get("/me", response_model=UsuarioOut)
async def leer_usuario_actual(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Obtiene el detalle del usuario autenticado (con su perfil)."""
    service = UsuarioService(db)
    usuario = await service.obtener_con_perfil(current_user.id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario


@router.patch("/me/perfil", response_model=UsuarioOut)
async def actualizar_mi_perfil(
    perfil_in: UsuarioPerfilCompletoUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Actualiza los datos editables del usuario y su perfil."""
    service = UsuarioService(db)
    usuario = await service.actualizar_perfil_completo(current_user.id, perfil_in)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario


@router.get("/{usuario_id}", response_model=UsuarioConRoles)
async def obtener_usuario(
    usuario_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Obtiene el detalle de un usuario junto con sus roles."""
    service = UsuarioService(db)
    usuario = await service.obtener_con_roles(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario


@router.patch("/{usuario_id}", response_model=UsuarioOut)
async def actualizar_usuario(
    usuario_id: int,
    usuario_in: UsuarioUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Actualiza datos parciales de un usuario."""
    service = UsuarioService(db)
    usuario = await service.actualizar(usuario_id, usuario_in)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario
