from typing import Annotated

from fastapi import APIRouter, Depends
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.auth import Token
from app.services.auth_service import AuthService

router = APIRouter()

@router.post("/login", response_model=Token)
async def login_for_access_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: AsyncSession = Depends(get_db)
):
    """
    Inicia sesión obteniendo un Access Token (JWT).
    Se usa form-data (username y password). En nuestro caso, username debe ser el email.
    """
    auth_service = AuthService(db)
    # OAuth2PasswordRequestForm usa el campo 'username', pero internamente usamos email.
    return await auth_service.authenticate_user(email=form_data.username, password=form_data.password)
