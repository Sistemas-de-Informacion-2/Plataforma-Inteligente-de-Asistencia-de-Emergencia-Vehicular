# backend/app/api/v1/endpoints/talleres.py
"""
Endpoints: Talleres, Sucursales y Onboarding Todo-en-Uno.
Nota de seguridad: cada endpoint tiene su propia dependencia de auth.
El endpoint /onboarding es PÚBLICO (no requiere JWT).
"""

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.elements import WKTElement

from app.core.database import get_db
from app.core.security import hash_password, create_access_token
from app.api.deps import get_current_user, get_current_admin
from app.models.usuario import Usuario
from app.models.admin import Admin
from app.models.taller import Taller, Sucursal
from app.models.rol import Rol, UsuarioRol
from app.schemas.taller import (
    TallerCreate, TallerOut, TallerConSucursales, TallerUpdate,
    SucursalCreate, SucursalOut, SucursalUpdate
)
from app.schemas.onboarding import TallerOnboardingRequest, TallerOnboardingResponse
from app.services.taller_service import TallerService, SucursalService
from app.repositories.usuario_repository import UsuarioRepository

router = APIRouter()


# ═══════════════════════════════════════════════════════════════
#  ONBOARDING TODO-EN-UNO (PÚBLICO — Sin JWT)
# ═══════════════════════════════════════════════════════════════

@router.post(
    "/onboarding",
    response_model=TallerOnboardingResponse,
    status_code=status.HTTP_201_CREATED,
)
async def onboarding_taller(
    data: TallerOnboardingRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Registro completo de un Admin de Taller en una transacción atómica.

    Crea en secuencia:
      1. Usuario (con password hasheado)
      2. UsuarioRol (rol ADMIN_TALLER)
      3. Admin (vinculado al usuario)
      4. Taller (vinculado al admin)
      5. Sucursal (vinculada al taller, con geometría PostGIS)

    Usa flush() entre pasos para obtener IDs.
    El commit() final lo gestiona get_db().
    Si cualquier paso falla → rollback automático.
    """
    usuario_repo = UsuarioRepository(db)

    # ── Paso 1: Validar unicidad ──────────────────────────────
    if await usuario_repo.email_exists(data.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El email '{data.email}' ya está registrado",
        )
    if await usuario_repo.ci_exists(data.ci):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El CI '{data.ci}' ya está registrado",
        )

    # ── Paso 2: Crear Usuario ─────────────────────────────────
    hashed_pw = hash_password(data.password)
    usuario = Usuario(
        nombre=data.nombre,
        email=data.email,
        password=hashed_pw,
        ci=data.ci,
        telefono=data.telefono,
    )
    db.add(usuario)
    await db.flush()  # → usuario.id disponible

    # ── Paso 3: Asignar rol ADMIN_TALLER ──────────────────────
    stmt = select(Rol).where(Rol.nombre == "ADMIN_TALLER")
    result = await db.execute(stmt)
    rol_admin = result.scalar_one_or_none()

    if not rol_admin:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Rol 'ADMIN_TALLER' no encontrado. Ejecute el seeder de roles.",
        )

    usuario_rol = UsuarioRol(
        usuario_id=usuario.id,
        rol_id=rol_admin.id,
    )
    db.add(usuario_rol)
    await db.flush()

    # ── Paso 4: Crear Admin ───────────────────────────────────
    admin = Admin(
        usuario_id=usuario.id,
        disponible=True,
    )
    db.add(admin)
    await db.flush()  # → admin.id disponible

    # ── Paso 5: Crear Taller ──────────────────────────────────
    taller = Taller(
        nombre=data.nombre_taller,
        descripcion=data.descripcion_taller,
        admin_id=admin.id,
    )
    db.add(taller)
    await db.flush()  # → taller.id disponible

    # ── Paso 6: Crear Sucursal (con PostGIS) ──────────────────
    ubicacion = WKTElement(
        f"POINT({data.longitud} {data.latitud})", srid=4326
    )
    sucursal = Sucursal(
        nombre=data.nombre_sucursal,
        direccion=data.direccion_sucursal,
        latitud=data.latitud,
        longitud=data.longitud,
        telefono=data.telefono_sucursal,
        taller_id=taller.id,
        ubicacion=ubicacion,
    )
    db.add(sucursal)
    await db.flush()  # → sucursal.id disponible

    # ── Generar JWT para el nuevo admin ───────────────────────
    access_token = create_access_token(data={"sub": str(usuario.id)})

    return TallerOnboardingResponse(
        usuario_id=usuario.id,
        admin_id=admin.id,
        taller_id=taller.id,
        sucursal_id=sucursal.id,
        access_token=access_token,
    )


# ═══════════════════════════════════════════════════════════════
#  TALLERES (PROTEGIDOS)
# ═══════════════════════════════════════════════════════════════

@router.post("/", response_model=TallerOut, status_code=status.HTTP_201_CREATED)
async def crear_taller(
    taller_in: TallerCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Crea un nuevo taller.
    Auto-detecta el admin_id a partir del usuario autenticado.
    """
    # Buscar registro Admin vinculado al usuario autenticado
    stmt = select(Admin).where(Admin.usuario_id == current_user.id)
    result = await db.execute(stmt)
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes un perfil de Admin asociado. Solo admins pueden crear talleres.",
        )

    # Forzar el admin_id del usuario autenticado
    taller_in_data = taller_in.model_dump()
    taller_in_data["admin_id"] = admin.id

    service = TallerService(db)
    taller = await service.repo.create(taller_in_data)
    return taller


@router.get("/", response_model=list[TallerOut])
async def listar_talleres(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista todos los talleres."""
    service = TallerService(db)
    return await service.listar(skip=skip, limit=limit)


@router.get("/{taller_id}", response_model=TallerConSucursales)
async def obtener_taller(
    taller_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene un taller junto con sus sucursales."""
    service = TallerService(db)
    taller = await service.obtener_con_sucursales(taller_id)
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
    return taller


@router.patch("/{taller_id}", response_model=TallerOut)
async def actualizar_taller(
    taller_id: int,
    taller_in: TallerUpdate,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza datos parciales de un taller. Solo Admin."""
    service = TallerService(db)
    taller = await service.actualizar(taller_id, taller_in)
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
    return taller


# ═══════════════════════════════════════════════════════════════
#  SUCURSALES (PROTEGIDOS)
# ═══════════════════════════════════════════════════════════════

@router.post(
    "/{taller_id}/sucursales",
    response_model=SucursalOut,
    status_code=status.HTTP_201_CREATED,
)
async def crear_sucursal(
    taller_id: int,
    sucursal_in: SucursalCreate,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Crea una sucursal para un taller específico. Solo Admin."""
    if taller_id != sucursal_in.taller_id:
        raise HTTPException(status_code=400, detail="El ID del taller no coincide")

    service = SucursalService(db)
    return await service.crear(sucursal_in)


@router.get("/{taller_id}/sucursales", response_model=list[SucursalOut])
async def listar_sucursales_de_taller(
    taller_id: int,
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
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
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
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
