# backend/app/api/v1/endpoints/notificaciones_ws.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
import logging

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
    # 1. Validación de Token (Replicando get_current_user porque Depends no aplican igual en WS Handshake)
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

    # 2. Aceptar WS e Inyectar al Connection Manager
    await manager.connect(websocket, usuario_id)

    # 3. Mantener vivo el túnel (Heartbeat pasivo)
    try:
        while True:
            # Escucha mensajes del cliente (por ahora solo para el ping/pong o acks)
            data = await websocket.receive_text()
            # En notificaciones push-down, raramente el cliente manda requests fuertes por aquí,
            # pero podemos simplemente loguearlo o ignorarlo.
    except WebSocketDisconnect:
        manager.disconnect(usuario_id)
