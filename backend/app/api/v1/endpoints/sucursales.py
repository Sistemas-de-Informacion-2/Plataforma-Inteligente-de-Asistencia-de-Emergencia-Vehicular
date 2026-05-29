# backend/app/api/v1/endpoints/sucursales.py
"""
Endpoints: Gestión dedicada de Sucursales (Relaciones N:M).
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.api.deps import get_current_admin, get_current_user
from app.models.usuario import Usuario
from app.models.admin import Admin
from app.schemas.servicio import SucursalServicioOut
from app.schemas.solicitud_emergencia import SolicitudDetallada
from app.schemas.asignacion import AsignarMecanicoRequest
from app.services.taller_service import SucursalService
from app.services.solicitud_service import SolicitudService

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


@router.post(
    "/{sucursal_id}/solicitudes/{solicitud_id}/asignar",
    summary="Asignar un mecánico a una solicitud de emergencia",
    description=(
        "El admin del taller asigna un mecánico a la solicitud cuya oferta fue aceptada. "
        "Verifica que el mecánico no tenga otro trabajo activo."
    ),
)
async def asignar_mecanico_a_solicitud(
    sucursal_id: int,
    solicitud_id: int,
    body: AsignarMecanicoRequest,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint crítico: asigna un mecánico verificando su disponibilidad real.
    La solicitud debe estar en OFERTA_ACEPTADA.
    """
    admin_id = await obtener_admin_id(current_user, db)
    service = SolicitudService(db)

    try:
        asignacion = await service.asignar_mecanico(
            solicitud_id=solicitud_id,
            sucursal_id=sucursal_id,
            admin_id=admin_id,
            empleado_id=body.empleado_id,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return {
        "message": "Mecánico asignado exitosamente. Se le ha notificado para que acepte.",
        "asignacion_id": asignacion.id,
        "empleado_id": asignacion.empleado_id,
        "estado_solicitud": "ESPERANDO_CONFIRMACION_MECANICO",
    }


@router.get(
    "/{sucursal_id}/solicitudes/pendientes",
    response_model=list[SolicitudDetallada],
    summary="Listar solicitudes pendientes de aceptación para una sucursal",
    description=(
        "Retorna las solicitudes en estado ESPERANDO_ACEPTACION_TALLER. "
        "Se usa para la carga inicial del Panel de Despacho."
    ),
)
async def listar_solicitudes_pendientes_sucursal(
    sucursal_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Carga inicial del panel de despacho: retorna todas las solicitudes
    en ESPERANDO_ACEPTACION_TALLER con evidencias y diagnóstico embebidos.
    """
    admin_id = await obtener_admin_id(current_user, db)

    # Validar que la sucursal pertenezca al admin
    from app.repositories.taller_repository import TallerRepository
    taller_repo = TallerRepository(db)
    sucursales_propias = await taller_repo.get_sucursal_ids_by_admin(admin_id)
    if sucursal_id not in sucursales_propias:
        raise HTTPException(status_code=403, detail="Esta sucursal no te pertenece")

    service = SolicitudService(db)
    from app.models.solicitud_emergencia import EstadoSolicitud
    solicitudes = await service.listar_por_estado(EstadoSolicitud.ESPERANDO_PUJAS)
    return solicitudes


@router.get(
    "/{sucursal_id}/solicitudes/en-proceso",
    response_model=list[SolicitudDetallada],
    summary="Listar solicitudes en proceso para una sucursal",
    description="Retorna las solicitudes en estado EN_PROCESO que ya fueron aceptadas pero aún no se ha cobrado.",
)
async def listar_solicitudes_en_proceso_sucursal(
    sucursal_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Solicitudes aceptadas (EN_PROCESO) para el panel de cobro."""
    admin_id = await obtener_admin_id(current_user, db)

    from app.repositories.taller_repository import TallerRepository
    taller_repo = TallerRepository(db)
    sucursales_propias = await taller_repo.get_sucursal_ids_by_admin(admin_id)
    if sucursal_id not in sucursales_propias:
        raise HTTPException(status_code=403, detail="Esta sucursal no te pertenece")

    service = SolicitudService(db)
    from app.models.solicitud_emergencia import EstadoSolicitud
    # Listar solicitudes en progreso: todos los estados activos post-aceptación
    from app.models.asignacion import Asignacion, EstadoAsignacion
    from sqlalchemy.orm import selectinload
    from app.models.solicitud_emergencia import SolicitudEmergencia

    estados_en_proceso = [
        EstadoSolicitud.OFERTA_ACEPTADA,
        EstadoSolicitud.ESPERANDO_CONFIRMACION_MECANICO,
        EstadoSolicitud.EN_CAMINO,
        EstadoSolicitud.EN_SITIO,
    ]
    stmt = (
        select(SolicitudEmergencia)
        .join(Asignacion, Asignacion.solicitud_id == SolicitudEmergencia.id)
        .options(
            selectinload(SolicitudEmergencia.evidencias),
            selectinload(SolicitudEmergencia.diagnostico),
            selectinload(SolicitudEmergencia.vehiculo),
            selectinload(SolicitudEmergencia.asignaciones),
        )
        .where(
            SolicitudEmergencia.estado.in_(estados_en_proceso),
            SolicitudEmergencia.es_eliminado == False,
            Asignacion.sucursal_id == sucursal_id,
        )
        .order_by(SolicitudEmergencia.fecha_creacion.desc())
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


@router.get(
    "/{sucursal_id}/solicitudes/atendidas",
    response_model=list[SolicitudDetallada],
    summary="Listar solicitudes atendidas o finalizadas para una sucursal",
    description="Retorna las solicitudes en estado ATENDIDO.",
)
async def listar_solicitudes_atendidas_sucursal(
    sucursal_id: int,
    current_user: Usuario = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Solicitudes finalizadas (ATENDIDO) para el panel de despacho."""
    admin_id = await obtener_admin_id(current_user, db)

    from app.repositories.taller_repository import TallerRepository
    taller_repo = TallerRepository(db)
    sucursales_propias = await taller_repo.get_sucursal_ids_by_admin(admin_id)
    if sucursal_id not in sucursales_propias:
        raise HTTPException(status_code=403, detail="Esta sucursal no te pertenece")

    service = SolicitudService(db)
    from app.models.solicitud_emergencia import EstadoSolicitud
    solicitudes = await service.listar_por_sucursal_y_estado(sucursal_id, EstadoSolicitud.FINALIZADO)
    return solicitudes


from pydantic import BaseModel, Field

class ResenaCreate(BaseModel):
    puntuacion: int = Field(..., ge=1, le=5)
    comentario: str | None = None

@router.post(
    "/{sucursal_id}/resenas",
    status_code=status.HTTP_201_CREATED,
    summary="Dejar una reseña al taller",
    description="Permite al cliente calificar y dejar un comentario al finalizar el servicio."
)
async def crear_resena_taller(
    sucursal_id: int,
    resena: ResenaCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.models.resena import ResenaForo
    
    nueva_resena = ResenaForo(
        puntuacion=resena.puntuacion,
        comentario=resena.comentario,
        sucursal_id=sucursal_id,
        usuario_id=current_user.id
    )
    
    db.add(nueva_resena)
    await db.commit()
    
    return {"message": "Reseña guardada exitosamente"}
