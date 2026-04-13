import os
import shutil
import uuid
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.usuario import Usuario
from app.models.evidencia import TipoEvidencia
from app.schemas.solicitud_emergencia import SolicitudCreate
from app.schemas.evidencia import EvidenciaCreate
from app.services.solicitud_service import SolicitudService

router = APIRouter()

UPLOAD_DIR = "uploads"

# Asegurar que el directorio de subidas exista
os.makedirs(UPLOAD_DIR, exist_ok=True)

async def guardar_archivo(file: UploadFile) -> str:
    """Guarda un UploadFile en disco y retorna su ruta relativa."""
    ext = os.path.splitext(file.filename)[1] if file.filename else ""
    nombre_unico = f"{uuid.uuid4().hex}{ext}"
    ruta_relativa = f"/uploads/{nombre_unico}"
    ruta_fisica = os.path.join(UPLOAD_DIR, nombre_unico)
    
    # Escribir a disco
    with open(ruta_fisica, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    return ruta_relativa

@router.post("/")
async def crear_incidente_multipart(
    latitud: float = Form(...),
    longitud: float = Form(...),
    vehiculo_id: Optional[int] = Form(None),
    descripcion: Optional[str] = Form(None),
    imagenes: List[UploadFile] = File([]),
    audio: Optional[UploadFile] = File(None),
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Endpoint conversacional/multipart para crear una emergencia (SOS).
    Recibe ubicación, textos y múltiples archivos opcionales.
    Delega a `SolicitudService.crear_nueva_solicitud` para desencadenar IA y Asignación.
    """
    try:
        # 1. Crear el esquema de la solicitud (Estado inicial PENDIENTE lo pone el Service)
        solicitud_in = SolicitudCreate(
            cliente_id=current_user.id,
            vehiculo_id=vehiculo_id,
            latitud=latitud,
            longitud=longitud,
            descripcion=descripcion
        )

        evidencias_in: List[EvidenciaCreate] = []

        # 2. Procesar imágenes si vienen
        # NOTA: En FastAPI, si mandas un campo File vacío, a veces llega una lista con un archivo vacío. Validamos nombre.
        for img_file in imagenes:
            if img_file.filename:
                url_img = await guardar_archivo(img_file)
                evidencias_in.append(
                    EvidenciaCreate(tipo=TipoEvidencia.IMAGEN, url=url_img)
                )

        # 3. Procesar audio si viene
        if audio and audio.filename:
            url_audio = await guardar_archivo(audio)
            evidencias_in.append(
                EvidenciaCreate(tipo=TipoEvidencia.AUDIO, url=url_audio)
            )

        # 4. Orquestar (Base de datos, IA, PostGIS)
        service = SolicitudService(db)
        
        # Le pasamos auto_diagnostico y auto_asignar en True para completar el flujo mágico
        resultado = await service.crear_nueva_solicitud(
            data=solicitud_in,
            evidencias=evidencias_in,
            auto_diagnostico=True,
            auto_asignar=True
        )

        # El resultado de service.crear_nueva_solicitud es un dict completo.
        # Retornamos estructurado tal cual lo hace /solicitudes/
        from app.schemas.solicitud_emergencia import SolicitudOut
        from app.schemas.diagnostico_ia import DiagnosticoIAOut
        from app.schemas.taller import SucursalOut

        diag_out = None
        if resultado.get("diagnostico"):
            diag_out = DiagnosticoIAOut.model_validate(resultado["diagnostico"])

        asignacion_out = None
        asignacion_res = resultado.get("asignacion_resultado")
        if asignacion_res:
            tecnico = asignacion_res.get("tecnico_asignado")
            # Dependiendo de tu implementación de tecnico, mapeamos lo básico:
            tecnico_out = {
                "id": tecnico.id,
                "usuario_id": tecnico.usuario_id,
                "especialidad": getattr(tecnico, "especialidad", None)
            } if tecnico else None

            asignacion_out = {
                "sucursal": SucursalOut.model_validate(asignacion_res["sucursal"]) if "sucursal" in asignacion_res else None,
                "distancia_km": asignacion_res.get("distancia_km"),
                "tecnico_asignado": tecnico_out
            }

        return {
            "solicitud": SolicitudOut.model_validate(resultado["solicitud"]),
            "diagnostico": diag_out,
            "asignacion": asignacion_out
        }

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error orquestando incidente: {str(e)}"
        )
