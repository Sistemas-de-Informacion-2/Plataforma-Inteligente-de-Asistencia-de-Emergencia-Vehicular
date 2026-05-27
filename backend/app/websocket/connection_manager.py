# backend/app/websocket/connection_manager.py
from fastapi import WebSocket
import logging

logger = logging.getLogger(__name__)

class ConnectionManager:
    def __init__(self):
        # Diccionario para almacenar conexiones activas (lista) asociadas al ID de usuario en string
        self.active_connections: dict[str, list[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, usuario_id: str):
        """Acepta la conexión WS y la registra bajo el usuario_id."""
        await websocket.accept()
        if usuario_id not in self.active_connections:
            self.active_connections[usuario_id] = []
        self.active_connections[usuario_id].append(websocket)
        logger.info(f"[WS] Usuario {usuario_id} conectado. Conexiones para este usuario: {len(self.active_connections[usuario_id])}")

    def disconnect(self, websocket: WebSocket, usuario_id: str):
        """Elimina una conexión activa específica del usuario."""
        if usuario_id in self.active_connections:
            if websocket in self.active_connections[usuario_id]:
                self.active_connections[usuario_id].remove(websocket)
                logger.info(f"[WS] Dispositivo desconectado para usuario {usuario_id}.")
            if not self.active_connections[usuario_id]:
                del self.active_connections[usuario_id]
                logger.info(f"[WS] Usuario {usuario_id} totalmente desconectado.")

    async def send_personal_message(self, message: dict, usuario_id: str):
        """Envía un diccionario JSON serializado a todos los WebSockets del usuario específico."""
        websockets = self.active_connections.get(usuario_id, [])
        if websockets:
            dead_sockets = []
            for websocket in websockets:
                try:
                    await websocket.send_json(message)
                except RuntimeError as e:
                    logger.error(f"[WS] Error enviando mensaje a una conexión de {usuario_id}: {e}")
                    dead_sockets.append(websocket)
            
            # Limpiar sockets muertos
            for ws in dead_sockets:
                self.disconnect(ws, usuario_id)
            
            logger.info(f"[WS] Mensaje enviado a {usuario_id} en {len(websockets) - len(dead_sockets)} dispositivos.")
        else:
            logger.warning(f"[WS] Usuario {usuario_id} no está conectado. Mensaje descartado.")

    async def broadcast_to_users(self, message: dict, usuario_ids: list[str]):
        """
        Envía un mensaje a múltiples usuarios conectados.
        Ignora silenciosamente a los usuarios no conectados.
        """
        enviados = 0
        for uid in usuario_ids:
            websockets = self.active_connections.get(uid, [])
            dead_sockets = []
            for websocket in websockets:
                try:
                    await websocket.send_json(message)
                    enviados += 1
                except RuntimeError as e:
                    logger.error(f"[WS] Error en broadcast a {uid}: {e}")
                    dead_sockets.append(websocket)
                    
            for ws in dead_sockets:
                self.disconnect(ws, uid)

        logger.info(
            f"[WS] Broadcast '{message.get('type', '')}' entregado a {enviados} dispositivos."
        )
        return enviados

    def is_connected(self, usuario_id: str) -> bool:
        """Verifica si un usuario tiene al menos una conexión WebSocket activa."""
        return usuario_id in self.active_connections and len(self.active_connections[usuario_id]) > 0

