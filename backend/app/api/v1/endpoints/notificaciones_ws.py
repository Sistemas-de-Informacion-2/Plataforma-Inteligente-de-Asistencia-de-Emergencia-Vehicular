# backend/app/api/v1/endpoints/notificaciones_ws.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
import logging
import json

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
                    cliente_id = msg_json.get("cliente_id")
                    if cliente_id:
                        # Enviamos el mismo mensaje al cliente
                        await manager.send_personal_message(msg_json, str(cliente_id))
                        
                # Reenvío de señalización de llamadas VoIP
                elif msg_json.get("type") in ["CALL_OFFER", "CALL_ANSWER", "CALL_END", "CALL_DECLINE"]:
                    target_id = msg_json.get("target_id")
                    if target_id:
                        msg_json["sender_id"] = usuario_id
                        await manager.send_personal_message(msg_json, str(target_id))
                                
            except json.JSONDecodeError:
                pass
            except Exception as e:
                logger.error(f"[WS] Error procesando mensaje entrante: {e}")
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, usuario_id)

