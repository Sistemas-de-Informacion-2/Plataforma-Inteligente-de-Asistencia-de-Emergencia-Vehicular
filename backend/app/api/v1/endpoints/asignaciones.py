# backend/app/api/v1/endpoints/asignaciones.py
"""
Endpoints: Flujo de Ejecución del Mecánico.

POST /api/v1/asignaciones/{id}/respuesta  → Aceptar o rechazar asignación.
POST /api/v1/asignaciones/{id}/llegada    → Marcar 'Ya llegué'.
POST /api/v1/asignaciones/{id}/finalizar  → Finalizar el trabajo.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_tecnico_o_admin
from app.models.usuario import Usuario
from app.schemas.asignacion import MecanicoRespuestaCreate, AsignacionOut
from app.services.solicitud_service import SolicitudService

router = APIRouter()


@router.get(
    "/me/activa",
    response_model=AsignacionOut,
    summary="Obtiene la asignación activa del mecánico",
    description="Retorna la asignación en curso (si existe) para el mecánico autenticado.",
)
async def obtener_asignacion_activa_me(
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.services.empleado_service import EmpleadoService
    from app.services.asignacion_service import AsignacionService

    empleado_service = EmpleadoService(db)
    empleado = await empleado_service.obtener_por_usuario(current_user.id)

    if not empleado:
        # Si es Admin_Taller sin empleado (auto-asignación), la lógica puede variar,
        # pero para el app móvil del técnico, asumiremos que tiene empleado asociado.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No eres un empleado activo.")

    asignacion_service = AsignacionService(db)
    asignacion = await asignacion_service.obtener_asignacion_activa_por_empleado(empleado.id)
    
    if not asignacion:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No tienes asignaciones activas.")

    return asignacion


@router.get(
    "/me/historial",
    response_model=list[AsignacionOut],
    summary="Obtiene el historial de asignaciones del mecánico",
    description="Retorna todas las asignaciones del mecánico autenticado (pendientes, rechazadas, completadas).",
)
async def obtener_historial_asignaciones_me(
    skip: int = 0,
    limit: int = 100,
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.services.empleado_service import EmpleadoService
    from app.repositories.asignacion_repository import AsignacionRepository

    empleado_service = EmpleadoService(db)
    empleado = await empleado_service.obtener_por_usuario(current_user.id)

    if not empleado:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No eres un empleado activo.")

    asignacion_repo = AsignacionRepository(db)
    asignaciones = await asignacion_repo.get_historial_por_empleado(empleado.id, skip=skip, limit=limit)
    
    return asignaciones

from pydantic import BaseModel
class UbicacionMecanico(BaseModel):
    latitud: float
    longitud: float

@router.post(
    "/{asignacion_id}/ubicacion",
    summary="Enviar ubicación en tiempo real del mecánico",
    description="Emite la ubicación del mecánico al cliente vía WebSocket.",
)
async def actualizar_ubicacion_mecanico(
    asignacion_id: int,
    ubicacion: UbicacionMecanico,
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    from app.repositories.asignacion_repository import AsignacionRepository
    from app.services.empleado_service import EmpleadoService
    from app.api.v1.endpoints.notificaciones_ws import manager
    from app.models.solicitud_emergencia import SolicitudEmergencia
    
    empleado_service = EmpleadoService(db)
    empleado = await empleado_service.obtener_por_usuario(current_user.id)
    if not empleado:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
        
    asignacion_repo = AsignacionRepository(db)
    asignacion = await asignacion_repo.get_by_id(asignacion_id)
    if not asignacion or asignacion.empleado_id != empleado.id:
        raise HTTPException(status_code=403, detail="Asignación no válida")
        
    # Emitir ubicación por WS al cliente
    solicitud = await db.execute(select(SolicitudEmergencia).where(SolicitudEmergencia.id == asignacion.solicitud_id))
    solicitud_obj = solicitud.scalar_one_or_none()
    
    if solicitud_obj:
        await manager.send_personal_message(
            {
                "type": "MECANICO_UBICACION",
                "asignacion_id": asignacion_id,
                "latitud": ubicacion.latitud,
                "longitud": ubicacion.longitud,
            },
            str(solicitud_obj.cliente_id)
        )
    return {"message": "Ubicación actualizada"}


@router.post(
    "/{asignacion_id}/respuesta",
    response_model=AsignacionOut,
    summary="Mecánico acepta o rechaza una asignación",
    description=(
        "El mecánico responde a su asignación. Si acepta, la solicitud pasa "
        "a EN_CAMINO y el cliente es notificado. Si rechaza, se guarda el motivo "
        "y el admin es notificado para reasignar."
    ),
)
async def responder_asignacion(
    asignacion_id: int,
    body: MecanicoRespuestaCreate,
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint protegido por JWT (rol MECANICO o ADMIN_TALLER).
    Valida que la asignación pertenezca al técnico autenticado o al Admin dueño.
    """
    service = SolicitudService(db)

    try:
        asignacion = await service.responder_asignacion_mecanico(
            asignacion_id=asignacion_id,
            usuario_id=current_user.id,
            aceptar=body.aceptar,
            motivo_rechazo=body.motivo_rechazo,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return asignacion


@router.post(
    "/{asignacion_id}/llegada",
    response_model=AsignacionOut,
    summary="Mecánico marca que llegó al sitio",
    description=(
        "El mecánico presiona 'Ya llegué'. La solicitud pasa a EN_SITIO "
        "y el cliente es notificado en tiempo real."
    ),
)
async def marcar_llegada(
    asignacion_id: int,
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Cambia el estado de la asignación y la solicitud a EN_SITIO.
    """
    service = SolicitudService(db)

    try:
        asignacion = await service.marcar_llegada(
            asignacion_id=asignacion_id,
            usuario_id=current_user.id,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return asignacion


from app.schemas.asignacion import MecanicoRespuestaCreate, AsignacionOut, MecanicoFinalizarCreate

@router.post(
    "/{asignacion_id}/finalizar",
    response_model=AsignacionOut,
    summary="Finalizar el trabajo de emergencia",
    description=(
        "El mecánico o admin finaliza el servicio. La solicitud pasa a FINALIZADO "
        "y el cliente es notificado para proceder al pago."
    ),
)
async def finalizar_trabajo(
    asignacion_id: int,
    body: MecanicoFinalizarCreate,
    current_user: Usuario = Depends(get_current_tecnico_o_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Cambia la asignación a COMPLETADA y la solicitud a FINALIZADO.
    Prepara el terreno para el módulo de pagos.
    """
    service = SolicitudService(db)

    try:
        asignacion = await service.finalizar_trabajo(
            asignacion_id=asignacion_id,
            usuario_id=current_user.id,
            monto_total=body.monto_total,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return asignacion
