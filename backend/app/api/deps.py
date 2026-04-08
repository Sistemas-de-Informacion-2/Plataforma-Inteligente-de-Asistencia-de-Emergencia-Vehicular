from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.usuario import Usuario
from app.services.usuario_service import UsuarioService

settings = get_settings()

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_PREFIX}/auth/login"
)

async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: AsyncSession = Depends(get_db)
) -> Usuario:
    """Verifica el token JWT y devuelve el usuario autenticado (con roles y perfil)."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception
        
    user_id: str | None = payload.get("sub")
    if user_id is None:
        raise credentials_exception
        
    # Validar que el usuario exista
    service = UsuarioService(db)
    user = await service.obtener_con_roles(int(user_id))
    if user is None:
        raise credentials_exception
        
    return user


def require_roles(required_roles: list[str]):
    """Generador de dependencia para requerir roles específicos."""
    def role_checker(
        current_user: Annotated[Usuario, Depends(get_current_user)]
    ) -> Usuario:
        user_roles = [rol.rol.nombre for rol in current_user.roles]
        if not any(role in user_roles for role in required_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes los permisos necesarios para acceder a este recurso"
            )
        return current_user
    return role_checker

# Dependencias predefinidas por rol
get_current_cliente = require_roles(["CLIENTE"])
get_current_tecnico = require_roles(["TECNICO"])
get_current_admin = require_roles(["ADMIN_TALLER"])
