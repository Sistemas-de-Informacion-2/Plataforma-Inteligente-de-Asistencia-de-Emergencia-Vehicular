# backend/app/api/v1/endpoints/notificaciones_ws.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
import logging
import json

from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.models.solicitud_emergencia import SolicitudEmergencia
from app.core.security import decode_access_token
from app.websocket.connection_manager import ConnectionManager

logger = logging.getLogger(__name__)

router = APIRouter()

# Instancia global del manager que mantendrá el estado de las conexiones
manager = ConnectionManager()

@router.websocket("/")
async def websocket_endpoint(websocket: WebSocket, token: str | None = None):
    """
    Túnel WebSocket para notificaciones en tiempo real al frontend.
    Requiere un query parameter `token` para validar y extraer el ID del usuario.
    """
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Missing Token")
        logger.warning("[WS] Conexión rechazada: Token ausente en query params.")
        return

    payload = decode_access_token(token)
    if not payload:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid Token")
        logger.warning("[WS] Conexión rechazada: Token inválido.")
        return

    usuario_id = str(payload.get("sub"))
    if not usuario_id or usuario_id == "None":
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid Subject")
        logger.warning("[WS] Conexión rechazada: Usuario vacío o inválido en payload.")
        return

    await manager.connect(websocket, usuario_id)

    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg_json = json.loads(data)
                
                # Reenvío de posición del mecánico al cliente
                if msg_json.get("type") == "UPDATE_LOCATION":
                    solicitud_id = msg_json.get("solicitud_id")
                    if solicitud_id:
                        async with AsyncSessionLocal() as session:
                            stmt = select(SolicitudEmergencia).where(SolicitudEmergencia.id == solicitud_id)
                            result = await session.execute(stmt)
                            solicitud = result.scalar_one_or_none()
                            
                            if solicitud and solicitud.usuario_id:
                                cliente_id_str = str(solicitud.usuario_id)
                                # Enviamos el mismo mensaje al cliente
                                await manager.send_personal_message(msg_json, cliente_id_str)
                                
            except json.JSONDecodeError:
                pass
            except Exception as e:
                logger.error(f"[WS] Error procesando mensaje entrante: {e}")
                
    except WebSocketDisconnect:
        manager.disconnect(usuario_id)

