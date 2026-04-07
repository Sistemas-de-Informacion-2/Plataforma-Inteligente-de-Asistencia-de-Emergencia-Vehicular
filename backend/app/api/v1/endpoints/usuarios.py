from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.usuario import UsuarioCreate, UsuarioOut, UsuarioUpdate, UsuarioConRoles
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
