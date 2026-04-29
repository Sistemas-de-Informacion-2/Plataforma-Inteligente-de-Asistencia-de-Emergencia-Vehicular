# backend/app/api/v1/endpoints/incidentes.py
"""
Endpoint: POST /api/v1/incidentes/
Flujo principal de reporte de emergencia vehicular.
Fase 1 — Modelo 'Uber para Mecánicos Inverso':
  1. Recibe multipart (ubicación, imágenes, audio, descripción).
  2. Procesa con Whisper (transcripción local) + Gemini (diagnóstico IA).
  3. Persiste Solicitud, Evidencias y DiagnosticoIA en BD.
  4. Busca sucursales aptas con PostGIS (sin asignar).
  5. Retorna SolicitudRecomendacionOut para que el cliente elija.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.usuario import Usuario
from app.models.evidencia import TipoEvidencia
from app.schemas.solicitud_emergencia import (
    SolicitudCreate, SolicitudOut, SolicitudDetallada, SolicitudRecomendacionOut,
    SucursalRecomendada, SolicitudSeleccionTaller,
)
from app.schemas.evidencia import EvidenciaCreate
from app.schemas.diagnostico_ia import DiagnosticoIAOut
from app.services.solicitud_service import SolicitudService
from app.services.ia_service import asistente_ia
from app.services.storage_service import StorageService, get_storage_service

router = APIRouter()


@router.post(
    "/",
    response_model=SolicitudRecomendacionOut,
    status_code=status.HTTP_201_CREATED,
    summary="Reportar emergencia vehicular (SOS)",
    description=(
        "Procesa un reporte de emergencia con IA y retorna "
        "una lista de talleres recomendados para que el cliente elija."
    ),
)
async def crear_incidente_multipart(
    latitud: float = Form(...),
    longitud: float = Form(...),
    vehiculo_id: Optional[int] = Form(None),
    descripcion: Optional[str] = Form(None),
    imagenes: List[UploadFile] = File([]),
    audio: Optional[UploadFile] = File(None),
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    storage: StorageService = Depends(get_storage_service),
):
    """
    Endpoint SOS — Fase 1: Recomendación sin auto-asignación.
    Flujo:
      1. Guarda archivos multimedia via StorageService.
      2. Procesa audio con Whisper + imagen/descripción con Gemini.
      3. Persiste Solicitud, Evidencias y DiagnosticoIA.
      4. Busca talleres cercanos y aptos (PostGIS).
      5. Retorna recomendaciones al cliente.

    El cliente usará otro endpoint (Fase 2) para confirmar su elección.
    """
    try:
        # ── 1. Construir el payload de entrada ────────────────
        solicitud_in = SolicitudCreate(
            cliente_id=current_user.id,
            vehiculo_id=vehiculo_id,
            latitud=latitud,
            longitud=longitud,
            descripcion=descripcion
        )

        evidencias_in: List[EvidenciaCreate] = []
        ruta_fisica_img = None
        ruta_fisica_audio = None

        # ── 2. Procesar imágenes ──────────────────────────────
        for i, img_file in enumerate(imagenes):
            if img_file.filename:
                r_rel, r_fis = await storage.upload_file_with_path(img_file, "evidencias")
                evidencias_in.append(EvidenciaCreate(tipo=TipoEvidencia.IMAGEN, url=r_rel))
                if i == 0:  # Solo la primera foto a Gemini para ahorrar tokens
                    ruta_fisica_img = r_fis

        # ── 3. Procesar audio ─────────────────────────────────
        if audio and audio.filename:
            r_rel, r_fis = await storage.upload_file_with_path(audio, "evidencias")
            evidencias_in.append(EvidenciaCreate(tipo=TipoEvidencia.AUDIO, url=r_rel))
            ruta_fisica_audio = r_fis

        # ── 4. Pipeline de IA: Whisper + Gemini ───────────────
        diagnostico_ia = asistente_ia.procesar_sos(
            descripcion=descripcion,
            ruta_audio=ruta_fisica_audio,
            ruta_imagen=ruta_fisica_img
        )

        # ── 5. Lógica de confianza → estado inicial ──────────
        confianza = diagnostico_ia.get("confianza", 0.0)
        
        if confianza < 0.4:
            estado_calculado = "RECHAZADO_POR_IA"
        elif confianza < 0.7:
            estado_calculado = "REQUIERE_VALIDACION"
        else:
            estado_calculado = "PENDIENTE"  # Se actualizará a PENDIENTE_SELECCION_CLIENTE si hay talleres

        # ── 6. Orquestar: BD + PostGIS (sin auto-asignación) ─
        service = SolicitudService(db)
        
        resultado_db = await service.crear_solicitud_con_recomendaciones(
            solicitud_in=solicitud_in,
            evidencias_in=evidencias_in,
            diagnostico=diagnostico_ia,
            estado_inicial=estado_calculado
        )

        # ── 7. Serializar respuesta ──────────────────────────
        solicitud_obj = resultado_db["solicitud"]
        diagnostico_obj = resultado_db["diagnostico"]
        candidatos_raw = resultado_db.get("sucursales_recomendadas", [])

        # Refrescar la solicitud para obtener el estado actualizado
        await db.refresh(solicitud_obj)

        # Construir lista de SucursalRecomendada
        sucursales_out = [
            SucursalRecomendada(
                id=c["sucursal_id"],
                nombre=c["sucursal_nombre"],
                direccion=c.get("sucursal_direccion"),
                telefono=c.get("sucursal_telefono"),
                latitud=c["sucursal_latitud"],
                longitud=c["sucursal_longitud"],
                taller_id=c["taller_id"],
                taller_nombre=c["taller_nombre"],
                distancia_km=c["distancia_km"],
                tiene_servicio=c["tiene_servicio"],
                tecnicos_disponibles=len(c.get("tecnicos_disponibles", [])),
                score=c["score"],
                eta_minutos=max(5, round(c["distancia_km"] * 3)),
            )
            for c in candidatos_raw
        ]

        return SolicitudRecomendacionOut(
            solicitud=SolicitudOut.model_validate(solicitud_obj),
            diagnostico_ia=DiagnosticoIAOut.model_validate(diagnostico_obj),
            sucursales_recomendadas=sucursales_out,
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error orquestando incidente: {str(e)}"
        )

@router.post(
    "/{solicitud_id}/seleccionar-taller",
    summary="Seleccionar un taller para el incidente",
    description="Permite al cliente elegir un taller de la lista de recomendaciones. Cambia el estado a ESPERANDO_ACEPTACION_TALLER y notifica al taller."
)
async def seleccionar_taller(
    solicitud_id: int,
    seleccion: SolicitudSeleccionTaller,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Endpoint para que el cliente confirme su elección de taller.
    """
    service = SolicitudService(db)
    exito = await service.seleccionar_taller(
        solicitud_id=solicitud_id,
        sucursal_id=seleccion.sucursal_id,
        current_user_id=current_user.id
    )

    if not exito:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se pudo procesar la selección. Verifica que la solicitud exista, te pertenezca y esté en el estado correcto."
        )

    return {"message": "Taller seleccionado exitosamente. El taller ha sido notificado y debe aceptar la solicitud."}


@router.get(
    "/{solicitud_id}",
    response_model=SolicitudDetallada,
    summary="Obtener detalle de una solicitud",
    description="Retorna una solicitud con sus evidencias y diagnóstico IA embebidos.",
)
async def obtener_solicitud_detalle(
    solicitud_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint para obtener el detalle completo de una solicitud.
    Usado por Angular cuando llega un WebSocket con solo el solicitud_id.
    """
    service = SolicitudService(db)
    solicitud = await service.obtener_detallada(solicitud_id)
    if not solicitud:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Solicitud #{solicitud_id} no encontrada."
        )
    return solicitud

@router.post(
    "/{solicitud_id}/simular-finalizacion",
    summary="Simular finalización del servicio",
    description="Endpoint exclusivo para pruebas E2E. Cambia el estado a ATENDIDO y dispara el evento de reseña al cliente."
)
async def simular_finalizacion_servicio(
    solicitud_id: int,
    db: AsyncSession = Depends(get_db)
):
    from app.models.solicitud_emergencia import EstadoSolicitud
    service = SolicitudService(db)
    solicitud = await service.obtener_por_id(solicitud_id)
    
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
        
    await service.actualizar_estado(solicitud_id, EstadoSolicitud.ATENDIDO)
    
    try:
        from app.api.v1.endpoints.notificaciones_ws import manager
        await manager.send_personal_message(
            {
                "type": "SERVICIO_FINALIZADO",
                "solicitud_id": solicitud_id,
                "mensaje": "El servicio ha finalizado. Por favor califica la atención."
            },
            str(solicitud.cliente_id)
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"Error WS simulación: {e}")
        
    return {"message": "Simulación exitosa, cliente notificado."}