from fastapi import APIRouter, HTTPException, Query, Depends
import httpx
import logging
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.usuario import Usuario
from app.models.solicitud_emergencia import SolicitudEmergencia
from app.api.v1.endpoints.notificaciones_ws import manager

logger = logging.getLogger(__name__)

router = APIRouter()

class RecalcularRequest(BaseModel):
    lng1: float
    lat1: float
    lng2: float
    lat2: float
    solicitud_id: int

@router.get("/")
async def obtener_ruta(
    lng1: float = Query(..., description="Longitud origen"),
    lat1: float = Query(..., description="Latitud origen"),
    lng2: float = Query(..., description="Longitud destino"),
    lat2: float = Query(..., description="Latitud destino"),
    current_user: Usuario = Depends(get_current_user),
):
    """
    Obtiene la ruta más óptima entre dos coordenadas usando OSRM.
    Devuelve distancia (m), tiempo estimado (s) y polyline.
    """
    url = f"http://router.project-osrm.org/route/v1/driving/{lng1},{lat1};{lng2},{lat2}?overview=full&geometries=polyline"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=3.0)
            
            if response.status_code != 200:
                logger.error(f"[Routing] Error OSRM HTTP {response.status_code}: {response.text}")
                raise ValueError("Error en servicio de ruteo externo")
            
            data = response.json()
            if data.get("code") != "Ok" or not data.get("routes"):
                raise ValueError("No se encontró una ruta")
                
            route = data["routes"][0]
            
            return {
                "distance": route.get("distance", 0),
                "duration": route.get("duration", 0),
                "polyline": route.get("geometry", "")
            }
            
    except (httpx.RequestError, ValueError) as e:
        logger.error(f"[Routing] Falla de conexión a OSRM: {e}. Usando fallback.")
        # Fallback de línea recta (codificado en polyline para no romper el cliente)
        return {
            "distance": 0,
            "duration": 300, # 5 min default
            "polyline": ""
        }

@router.post("/recalcular")
async def recalcular_ruta(
    req: RecalcularRequest,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Recalcula la ruta y notifica proactivamente al cliente vía WebSocket.
    Solo invocado por el mecánico cuando se desvía de la ruta.
    """
    url = f"http://router.project-osrm.org/route/v1/driving/{req.lng1},{req.lat1};{req.lng2},{req.lat2}?overview=full&geometries=polyline"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=3.0)
            
            if response.status_code != 200:
                logger.error(f"[Routing] Error OSRM HTTP {response.status_code}: {response.text}")
                raise ValueError("Error en servicio de ruteo externo")
            
            data = response.json()
            if data.get("code") != "Ok" or not data.get("routes"):
                raise ValueError("No se encontró una ruta")
                
            route = data["routes"][0]
            
            payload = {
                "distance": route.get("distance", 0),
                "duration": route.get("duration", 0),
                "polyline": route.get("geometry", "")
            }
            
            # Emitir WS a cliente
            ws_message = {
                "type": "RUTA_ACTUALIZADA",
                "payload": payload
            }
            
            # Obtener cliente_id de la solicitud
            solicitud_result = await db.execute(select(SolicitudEmergencia).where(SolicitudEmergencia.id == req.solicitud_id))
            solicitud_obj = solicitud_result.scalar_one_or_none()
            
            if solicitud_obj:
                try:
                    await manager.send_personal_message(ws_message, str(solicitud_obj.cliente_id))
                except Exception as e:
                    logger.warning(f"[Routing] No se pudo enviar RUTA_ACTUALIZADA al cliente {solicitud_obj.cliente_id}: {e}")
            else:
                logger.warning(f"[Routing] No se encontró solicitud {req.solicitud_id} para enviar RUTA_ACTUALIZADA")
            
            return payload
            
    except (httpx.RequestError, ValueError) as e:
        logger.error(f"[Routing] Falla de conexión a OSRM: {e}")
        raise HTTPException(status_code=503, detail="Fallo ruteo externo")
