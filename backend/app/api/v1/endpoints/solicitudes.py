from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.solicitud_emergencia import EstadoSolicitud
from app.schemas.solicitud_emergencia import SolicitudCreate, SolicitudOut, SolicitudDetallada
from app.schemas.evidencia import EvidenciaCreate
from app.services.solicitud_service import SolicitudService

router = APIRouter()


@router.post("/", status_code=status.HTTP_201_CREATED)
async def crear_solicitud(
    solicitud_in: SolicitudCreate,
    evidencias: list[EvidenciaCreate] | None = None,
    auto_diagnostico: bool = True,
    auto_asignar: bool = True,
    db: AsyncSession = Depends(get_db)
) -> dict[str, Any]:
    """
    ENDPOINT ESTRELLA:
    Crea una solicitud de emergencia y orquesta el flujo completo:
    1. Guarda evidencias.
    2. Ejecuta diagnósticos de IA.
    3. Asigna el mejor taller usando PostGIS y scoring.
    4. Notifica al usuario.
    """
    service = SolicitudService(db)
    # Importante: Como la IA, Asignacion y Notificacion modifican y crean en BD,
    # el orquestador maneja su propia transacción fluida y el flush.
    try:
        resultado = await service.crear_nueva_solicitud(
            data=solicitud_in,
            evidencias=evidencias,
            auto_diagnostico=auto_diagnostico,
            auto_asignar=auto_asignar
        )
        
        from app.schemas.diagnostico_ia import DiagnosticoIAOut
        from app.schemas.taller import SucursalOut

        diag_out = None
        if resultado.get("diagnostico"):
            diag_out = DiagnosticoIAOut.model_validate(resultado["diagnostico"])

        asignacion_out = None
        asignacion_res = resultado.get("asignacion_resultado")
        if asignacion_res:
            tecnico = asignacion_res.get("tecnico_asignado")
            tecnico_out = None
            if tecnico:
                tecnico_out = {
                    "id": tecnico.id,
                    "usuario_id": tecnico.usuario_id,
                    "especialidad": tecnico.especialidad
                }

            asignacion_out = {
                "sucursal": SucursalOut.model_validate(asignacion_res["sucursal"]) if "sucursal" in asignacion_res else None,
                "distancia_km": asignacion_res.get("distancia_km"),
                "tecnico_asignado": tecnico_out
            }

        # Formatear la salida para que sea compatible con JSON
        return {
            "solicitud": SolicitudOut.model_validate(resultado["solicitud"]),
            "diagnostico": diag_out,
            "asignacion": asignacion_out
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error orquestando solicitud: {str(e)}"
        )


@router.get("/", response_model=list[SolicitudOut])
async def listar_solicitudes(
    cliente_id: int | None = None,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """Obtiene la lista de solicitudes (opcional por cliente)."""
    service = SolicitudService(db)
    if cliente_id:
        return await service.listar_por_cliente(cliente_id, skip, limit)
    return await service.listar_todas(skip, limit)


@router.get("/pendientes", response_model=list[SolicitudOut])
async def listar_solicitudes_pendientes(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """Obtiene el listado de solicitudes que aún esperan asignación (para los talleres)."""
    service = SolicitudService(db)
    return await service.listar_pendientes(skip, limit)


@router.get("/{solicitud_id}", response_model=SolicitudDetallada)
async def obtener_solicitud(
    solicitud_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Obtiene el detalle completo de una solicitud (con evidencias y diagnóstico)."""
    service = SolicitudService(db)
    solicitud = await service.obtener_detallada(solicitud_id)
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return solicitud


@router.patch("/{solicitud_id}/estado", response_model=SolicitudOut)
async def actualizar_estado_solicitud(
    solicitud_id: int,
    estado: EstadoSolicitud,
    db: AsyncSession = Depends(get_db)
):
    """Actualiza solo el estado de la solicitud y notifica al cliente."""
    service = SolicitudService(db)
    solicitud = await service.actualizar_estado(solicitud_id, estado)
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return solicitud
