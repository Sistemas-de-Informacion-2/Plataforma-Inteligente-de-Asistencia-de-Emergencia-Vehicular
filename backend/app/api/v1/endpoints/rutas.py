from fastapi import APIRouter, HTTPException, Query, Depends
import httpx
import logging
from app.api.deps import get_current_user
from app.models.usuario import Usuario

logger = logging.getLogger(__name__)

router = APIRouter()

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
