# backend/app/api/v1/endpoints/incidentes.py
import os
import shutil
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.usuario import Usuario
from app.models.evidencia import TipoEvidencia
from app.schemas.solicitud_emergencia import SolicitudCreate, SolicitudOut
from app.schemas.evidencia import EvidenciaCreate
from app.schemas.diagnostico_ia import DiagnosticoIAOut
from app.schemas.asignacion import AsignacionOut
from app.services.solicitud_service import SolicitudService
from app.services.ia_service import asistente_ia

router = APIRouter()

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

async def guardar_archivo(file: UploadFile) -> str:
    """Guarda un UploadFile en disco y retorna su ruta relativa."""
    ext = os.path.splitext(file.filename)[1] if file.filename else ""
    nombre_unico = f"{uuid.uuid4().hex}{ext}"
    ruta_fisica = os.path.join(UPLOAD_DIR, nombre_unico)
    ruta_relativa = f"/uploads/{nombre_unico}"
    
    with open(ruta_fisica, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    return ruta_relativa, ruta_fisica

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
    """Endpoint para crear una emergencia (SOS)."""
    try:
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

        # 2. Procesar imágenes si vienen
        for i, img_file in enumerate(imagenes):
            if img_file.filename:
                r_rel, r_fis = await guardar_archivo(img_file)
                evidencias_in.append(EvidenciaCreate(tipo=TipoEvidencia.IMAGEN, url=r_rel))
                if i == 0:  # Le pasamos solo la primera foto a Gemini para ahorrar tokens
                    ruta_fisica_img = r_fis

        # 3. Procesar audio 
        if audio and audio.filename:
            r_rel, r_fis = await guardar_archivo(audio)
            evidencias_in.append(EvidenciaCreate(tipo=TipoEvidencia.AUDIO, url=r_rel))
            ruta_fisica_audio = r_fis

        # 4. Llamar al Asistente de IA
        diagnostico_ia = asistente_ia.procesar_sos(
            descripcion=descripcion,
            ruta_audio=ruta_fisica_audio,
            ruta_imagen=ruta_fisica_img
        )

        # 5. Lógica de Confianza y Estado
        confianza = diagnostico_ia.get("confianza", 0.0)
        
        if confianza < 0.4:
            estado_calculado = "RECHAZADO_POR_IA" # Audio en silencio, foto negra, bromas
        elif confianza < 0.7:
            estado_calculado = "REQUIERE_VALIDACION" # La IA no está segura, un humano o el sistema pide más info
        else:
            estado_calculado = "PENDIENTE_ASIGNACION" # Diagnóstico confiable, listo para buscar mecánico

        print(f"Confianza: {confianza} -> Estado dictaminado: {estado_calculado}")
        print(f"Prioridad IA: {diagnostico_ia.get('prioridad')}")

        # 4. Orquestar (Base de datos, IA, PostGIS)
        service = SolicitudService(db)
        
        resultado_db = await service.crear_nueva_solicitud_con_ia(
            solicitud_in=solicitud_in,
            evidencias_in=evidencias_in,
            diagnostico=diagnostico_ia,
            estado_inicial=estado_calculado
        )

        raw_asignacion = resultado_db.get("asignacion_resultado", {})
        asignacion_dict = None
        if raw_asignacion and raw_asignacion.get("seleccionado"):
            mejor = raw_asignacion["seleccionado"]
            tecnicos = mejor.get("tecnicos_disponibles", [])
            asignacion_dict = {
                "sucursal": {
                    "id": mejor.get("sucursal_id"),
                    "nombre": mejor.get("sucursal_nombre", "")
                },
                "tecnico_asignado": tecnicos[0] if tecnicos else None,
                "distancia_km": mejor.get("distancia_km", 0.0),
                "tiempo_estimado": max(5.0, float(round(mejor.get("distancia_km", 0) * 3)))
            }

        return {
            "solicitud": SolicitudOut.model_validate(resultado_db["solicitud"]).model_dump(mode='json') if resultado_db.get("solicitud") else None,
            "diagnostico": DiagnosticoIAOut.model_validate(resultado_db["diagnostico"]).model_dump(mode='json') if resultado_db.get("diagnostico") else None,
            "asignacion_resultado": asignacion_dict,
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error orquestando incidente: {str(e)}")