# backend/app/services/auth_service.py
"""
Servicio de Autenticación.
"""
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.core.security import verify_password, create_access_token
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.auth import Token

class AuthService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = UsuarioRepository(session)

    async def authenticate_user(self, email: str, password: str) -> Token:
        """Autentica a un usuario y retorna su token de acceso."""
        user = await self.repo.get_by_email(email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Email o contraseña incorrectos",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        if not verify_password(password, user.password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Email o contraseña incorrectos",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        access_token = create_access_token(
            data={"sub": str(user.id)}
        )
        
        return Token(access_token=access_token, token_type="bearer")
