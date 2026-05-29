# backend/app/api/v1/endpoints/incidentes.py
"""
Endpoint: POST /api/v1/incidentes/
Flujo principal de reporte de emergencia vehicular.
Marketplace de Pujas (estilo inDrive):
  1. Recibe multipart (ubicación, imágenes, audio, descripción).
  2. Procesa con Whisper (transcripción local) + Gemini (diagnóstico IA).
  3. Persiste Solicitud, Evidencias y DiagnosticoIA en BD.
  4. Busca talleres cercanos con PostGIS y emite SOS vía WebSocket.
  5. Retorna SolicitudSOSOut (sin lista de sucursales — las pujas llegan en vivo).
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.usuario import Usuario
from app.models.evidencia import TipoEvidencia
from app.schemas.solicitud_emergencia import (
    SolicitudCreate, SolicitudOut, SolicitudDetallada, SolicitudSOSOut,
    SolicitudSeleccionTaller,
)
from app.schemas.puja import PujaSeleccion
from app.schemas.evidencia import EvidenciaCreate
from app.schemas.diagnostico_ia import DiagnosticoIAOut
from app.services.solicitud_service import SolicitudService
from app.services.ia_service import asistente_ia
from app.services.storage_service import StorageService, get_storage_service

router = APIRouter()


@router.post(
    "/",
    response_model=SolicitudSOSOut,
    status_code=status.HTTP_201_CREATED,
    summary="Reportar emergencia vehicular (SOS)",
    description=(
        "Procesa un reporte de emergencia con IA, emite un SOS a talleres cercanos "
        "vía WebSocket y retorna la solicitud creada. Las pujas llegarán en tiempo real."
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
    Endpoint SOS — Marketplace de Pujas (inDrive).
    Flujo:
      1. Guarda archivos multimedia via StorageService.
      2. Procesa audio con Whisper + imagen/descripción con Gemini.
      3. Persiste Solicitud, Evidencias y DiagnosticoIA.
      4. Broadcast SOS a admins de talleres cercanos vía WebSocket.
      5. Retorna solicitud + diagnóstico (las pujas llegan en vivo por WS).
    """
    try:
        # 1. Construir el payload de entrada
        solicitud_in = SolicitudCreate(
            cliente_id=current_user.id,
            vehiculo_id=vehiculo_id,
            latitud=latitud,
            longitud=longitud,
            descripcion=descripcion
        )

        evidencias_in: List[EvidenciaCreate] = []
        rutas_fisicas_imgs: List[str] = []
        ruta_fisica_audio = None

        # 2. Procesar imágenes (TODAS van a Gemini)
        for img_file in imagenes:
            if img_file.filename:
                r_rel, r_fis = await storage.upload_file_with_path(img_file, "evidencias")
                evidencias_in.append(EvidenciaCreate(tipo=TipoEvidencia.IMAGEN, url=r_rel))
                rutas_fisicas_imgs.append(r_fis)

        # 3. Procesar audio
        if audio and audio.filename:
            r_rel, r_fis = await storage.upload_file_with_path(audio, "evidencias")
            evidencias_in.append(EvidenciaCreate(tipo=TipoEvidencia.AUDIO, url=r_rel))
            ruta_fisica_audio = r_fis

        # 4. Pipeline de IA: Whisper + Gemini
        diagnostico_ia = asistente_ia.procesar_sos(
            descripcion=descripcion,
            ruta_audio=ruta_fisica_audio,
            rutas_imagenes=rutas_fisicas_imgs or None,
        )

        # 5. Lógica de confianza → estado inicial
        confianza = diagnostico_ia.get("confianza", 0.0)

        if confianza < 0.4:
            estado_calculado = "RECHAZADO_POR_IA"
        elif confianza < 0.7:
            estado_calculado = "REQUIERE_VALIDACION"
        else:
            estado_calculado = "PENDIENTE"  # Se actualizará a ESPERANDO_PUJAS si hay talleres

        # 6. Orquestar: BD + PostGIS + Broadcast SOS
        service = SolicitudService(db)

        resultado_db = await service.crear_solicitud_y_emitir_sos(
            solicitud_in=solicitud_in,
            evidencias_in=evidencias_in,
            diagnostico=diagnostico_ia,
            estado_inicial=estado_calculado
        )

        # 7. Serializar respuesta
        solicitud_obj = resultado_db["solicitud"]
        diagnostico_obj = resultado_db["diagnostico"]
        talleres_notificados = resultado_db.get("talleres_notificados", 0)

        # Refrescar la solicitud para obtener el estado actualizado
        await db.refresh(solicitud_obj)

        return SolicitudSOSOut(
            solicitud=SolicitudOut.model_validate(solicitud_obj),
            diagnostico_ia=DiagnosticoIAOut.model_validate(diagnostico_obj),
            talleres_notificados=talleres_notificados,
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error orquestando incidente: {str(e)}"
        )

@router.post(
    "/{solicitud_id}/seleccionar-puja",
    summary="Seleccionar la puja ganadora (Match Final)",
    description=(
        "El cliente elige su oferta favorita de las pujas recibidas. "
        "Crea la asignación, notifica al ganador y rechaza las demás pujas."
    ),
)
async def seleccionar_puja(
    solicitud_id: int,
    seleccion: PujaSeleccion,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint Match Final — el cliente confirma su puja favorita.
    Flujo:
      1. Valida pertenencia y estado ESPERANDO_PUJAS.
      2. Marca puja como ACEPTADA, rechaza las demás.
      3. Cambia solicitud a OFERTA_ACEPTADA.
      4. Crea Asignación.
      5. Notifica a ganador, perdedores y cliente vía WebSocket.
    """
    from app.services.puja_service import PujaService
    service = PujaService(db)

    try:
        resultado = await service.seleccionar_puja(
            solicitud_id=solicitud_id,
            puja_id=seleccion.puja_id,
            current_user_id=current_user.id,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    return {
        "message": "¡Oferta seleccionada exitosamente! El taller ha sido notificado.",
        "asignacion_id": resultado["asignacion_id"],
        "puja_ganadora": resultado["puja_ganadora"],
        "sucursal": resultado["sucursal"],
    }


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


@router.get(
    "/activa",
    response_model=SolicitudDetallada,
    summary="Obtener solicitud activa del cliente",
    description="Devuelve la solicitud en curso (PENDIENTE, ESPERANDO_PUJAS, etc.) del cliente autenticado."
)
async def obtener_solicitud_activa(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = SolicitudService(db)
    solicitud = await service.obtener_solicitud_activa_cliente(current_user.id)
    if not solicitud:
        raise HTTPException(status_code=404, detail="No tienes ninguna solicitud activa.")
    
    # Usamos el repositorio para obtenerla con detalles (diagnostico, vehiculo, etc)
    from app.repositories.solicitud_repository import SolicitudRepository
    repo = SolicitudRepository(db)
    detallada = await repo.get_detallada(solicitud.id)
    
    return detallada


@router.post(
    "/{solicitud_id}/cancelar",
    summary="Cancelar solicitud de emergencia",
    description="El cliente cancela su solicitud actual. Se notifica a los talleres para que dejen de pujar."
)
async def cancelar_solicitud_emergencia(
    solicitud_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = SolicitudService(db)
    try:
        await service.cancelar_solicitud_cliente(solicitud_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    return {"message": "Solicitud cancelada exitosamente."}