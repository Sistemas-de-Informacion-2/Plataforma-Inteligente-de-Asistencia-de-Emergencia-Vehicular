# backend/app/services/firebase_push_service.py
"""
Servicio de Push Notifications via Firebase Cloud Messaging (FCM).
Inicializa firebase_admin una sola vez y expone métodos para enviar pushes.
"""
import logging
from pathlib import Path
from typing import Optional

import firebase_admin
from firebase_admin import credentials, messaging

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_firebase_app: Optional[firebase_admin.App] = None


def _init_firebase():
    """Inicializa Firebase Admin SDK si aún no está inicializado."""
    global _firebase_app
    if _firebase_app is not None:
        return

    settings = get_settings()
    cred_path = settings.FIREBASE_CREDENTIALS_PATH
    if not cred_path:
        logger.warning("[FCM] FIREBASE_CREDENTIALS_PATH no configurado. Push deshabilitado.")
        return

    full_path = Path(cred_path)
    if not full_path.exists():
        logger.warning(f"[FCM] Archivo de credenciales no encontrado: {full_path}. Push deshabilitado.")
        return

    try:
        cred = credentials.Certificate(str(full_path))
        _firebase_app = firebase_admin.initialize_app(cred)
        logger.info("[FCM] ✅ Firebase Admin SDK inicializado correctamente.")
    except Exception as e:
        logger.error(f"[FCM] ❌ Error inicializando Firebase: {e}")


def enviar_push(
    token_fcm: str,
    titulo: str,
    cuerpo: str,
    data: dict | None = None
) -> bool:
    """
    Envía una notificación push a un dispositivo específico.
    Args:
        token_fcm: Token FCM del dispositivo destino.
        titulo: Título de la notificación.
        cuerpo: Cuerpo del mensaje.
        data: Datos adicionales (key-value strings) que llegan silenciosamente.
    Returns:
        True si se envió correctamente, False si hubo error.
    """
    _init_firebase()
    if _firebase_app is None:
        logger.warning("[FCM] Firebase no inicializado, push descartado.")
        return False

    try:
        # Construir el mensaje
        message = messaging.Message(
            notification=messaging.Notification(
                title=titulo,
                body=cuerpo,
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token_fcm,
            # Configuración Android
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    channel_id="emergencias",
                ),
            ),
        )
        response = messaging.send(message)
        logger.info(f"[FCM] ✅ Push enviado: {response}")
        return True

    except messaging.UnregisteredError:
        logger.warning(f"[FCM] Token FCM inválido/expirado: {token_fcm[:20]}...")
        return False
    except Exception as e:
        logger.error(f"[FCM] ❌ Error enviando push: {e}")
        return False


def enviar_push_multiple(
    tokens_fcm: list[str],
    titulo: str,
    cuerpo: str,
    data: dict | None = None
) -> int:
    """
    Envía push a múltiples dispositivos.
    Returns: número de envíos exitosos.
    """
    _init_firebase()
    if _firebase_app is None or not tokens_fcm:
        return 0

    try:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=titulo,
                body=cuerpo,
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            tokens=tokens_fcm,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    channel_id="emergencias",
                ),
            ),
        )
        response = messaging.send_each_for_multicast(message)
        logger.info(f"[FCM] Multicast: {response.success_count} exitosos, {response.failure_count} fallidos.")
        return response.success_count
    except Exception as e:
        logger.error(f"[FCM] Error en multicast: {e}")
        return 0
