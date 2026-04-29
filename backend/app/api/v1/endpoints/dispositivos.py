# backend/app/api/v1/endpoints/dispositivos.py
"""
Endpoints para gestión de dispositivos (token FCM).
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.usuario import Usuario

router = APIRouter()


class TokenFCMRequest(BaseModel):
    """Payload para registrar un token FCM."""
    token: str


@router.post(
    "/registrar-token",
    summary="Registrar token FCM del dispositivo",
    description="Guarda el token FCM para poder enviar push notifications al usuario autenticado."
)
async def registrar_token_fcm(
    payload: TokenFCMRequest,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Asocia el token FCM del dispositivo al usuario autenticado."""
    current_user.fcm_token = payload.token
    db.add(current_user)
    await db.commit()
    return {"message": "Token FCM registrado exitosamente."}
