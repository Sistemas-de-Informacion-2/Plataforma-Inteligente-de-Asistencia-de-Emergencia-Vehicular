# backend/app/websocket/connection_manager.py
from fastapi import WebSocket
import logging

logger = logging.getLogger(__name__)

class ConnectionManager:
    def __init__(self):
        # Diccionario para almacenar conexiones activas asociadas al ID de usuario en string
        self.active_connections: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, usuario_id: str):
        """Acepta la conexión WS y la registra bajo el usuario_id."""
        await websocket.accept()
        self.active_connections[usuario_id] = websocket
        logger.info(f"[WS] Usuario {usuario_id} conectado. Conexiones activas: {len(self.active_connections)}")

    def disconnect(self, usuario_id: str):
        """Elimina la conexión activa del usuario."""
        if usuario_id in self.active_connections:
            del self.active_connections[usuario_id]
            logger.info(f"[WS] Usuario {usuario_id} desconectado. Conexiones activas: {len(self.active_connections)}")

    async def send_personal_message(self, message: dict, usuario_id: str):
        """Envía un diccionario JSON serializado al WebSocket del usuario específico."""
        websocket = self.active_connections.get(usuario_id)
        if websocket:
            try:
                await websocket.send_json(message)
                logger.info(f"[WS] Mensaje enviado a {usuario_id}: {message}")
            except RuntimeError as e:
                logger.error(f"[WS] Error enviando mensaje a {usuario_id}: {e}")
                self.disconnect(usuario_id)
        else:
            logger.warning(f"[WS] Usuario {usuario_id} no está conectado. Mensaje descartado.")
