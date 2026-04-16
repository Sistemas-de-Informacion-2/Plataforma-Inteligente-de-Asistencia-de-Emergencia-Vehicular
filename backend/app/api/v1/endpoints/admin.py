# backend/app/api/v1/endpoints/admin.py
"""
Endpoints del Super Admin Dashboard.
CRUD maestro de Servicios + gestión/baneo de Usuarios.

SEGURIDAD: Todos los endpoints requieren rol SUPER_ADMIN.
El SUPER_ADMIN es la plataforma; NO es un Admin de taller.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.api.deps import get_current_super_admin
from app.models.usuario import Usuario
from app.schemas.servicio import ServicioCreate, ServicioUpdate, ServicioOut
from app.schemas.usuario import UsuarioOut
from app.repositories.servicio_repository import ServicioRepository
from app.repositories.usuario_repository import UsuarioRepository

router = APIRouter()


# GESTIÓN DE SERVICIOS (Catálogo Maestro)
@router.get("/servicios/", response_model=list[ServicioOut])
async def listar_servicios(
    skip: int = 0,
    limit: int = 100,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista el catálogo maestro de servicios/especialidades."""
    repo = ServicioRepository(db)
    return await repo.get_all(skip=skip, limit=limit)


@router.post(
    "/servicios/",
    response_model=ServicioOut,
    status_code=status.HTTP_201_CREATED,
)
async def crear_servicio(
    servicio_in: ServicioCreate,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Crea un nuevo servicio oficial en la plataforma (Ej: LLANTA, MOTOR, GENERAL)."""
    repo = ServicioRepository(db)

    # Verificar unicidad del nombre
    existente = await repo.get_by_field("nombre", servicio_in.nombre)
    if existente:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ya existe un servicio con el nombre '{servicio_in.nombre}'",
        )

    return await repo.create(servicio_in.model_dump())


@router.get("/servicios/{servicio_id}", response_model=ServicioOut)
async def obtener_servicio(
    servicio_id: int,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene el detalle de un servicio por su ID."""
    repo = ServicioRepository(db)
    servicio = await repo.get_by_id(servicio_id)
    if not servicio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Servicio no encontrado",
        )
    return servicio


@router.patch("/servicios/{servicio_id}", response_model=ServicioOut)
async def actualizar_servicio(
    servicio_id: int,
    servicio_in: ServicioUpdate,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza datos parciales de un servicio (nombre, descripción)."""
    repo = ServicioRepository(db)
    servicio = await repo.get_by_id(servicio_id)
    if not servicio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Servicio no encontrado",
        )
    return await repo.update(servicio_id, servicio_in.model_dump(exclude_unset=True))


@router.delete("/servicios/{servicio_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_servicio(
    servicio_id: int,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Elimina un servicio del catálogo. Hard delete (Servicio no tiene AuditableMixin)."""
    repo = ServicioRepository(db)
    servicio = await repo.get_by_id(servicio_id)
    if not servicio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Servicio no encontrado",
        )
    await repo.delete(servicio_id)


# GESTIÓN DE USUARIOS (Listado / Baneo)
@router.get("/usuarios/", response_model=list[UsuarioOut])
async def listar_usuarios(
    skip: int = 0,
    limit: int = 100,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista todos los usuarios de la plataforma (paginado)."""
    repo = UsuarioRepository(db)
    return await repo.get_all(skip=skip, limit=limit)


@router.get("/usuarios/{usuario_id}", response_model=UsuarioOut)
async def obtener_usuario(
    usuario_id: int,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene el detalle de un usuario."""
    repo = UsuarioRepository(db)
    usuario = await repo.get_with_perfil(usuario_id)
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )
    return usuario


@router.patch("/usuarios/{usuario_id}/ban", response_model=UsuarioOut)
async def banear_usuario(
    usuario_id: int,
    current_admin: Usuario = Depends(get_current_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Banea a un usuario (Soft Delete simple).
    NO ofusca email/CI → el usuario baneado NO puede re-registrarse
    con los mismos datos (intencional para fraude).
    """
    repo = UsuarioRepository(db)
    usuario = await repo.get_with_perfil(usuario_id)
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )
    if usuario.es_eliminado:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El usuario ya está baneado",
        )

    await repo.delete(usuario_id)

    # Re-fetch para devolver el estado actualizado
    usuario_actualizado = await repo.get_by_id(usuario_id)
    # get_by_id excluye eliminados, así que buscamos directo
    from sqlalchemy import select
    stmt = select(Usuario).where(Usuario.id == usuario_id)
    result = await db.execute(stmt)
    return result.scalar_one()