"""
Configuración centralizada de la aplicación.
Usa Pydantic Settings para leer variables de entorno desde .env
"""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuración global de la aplicación cargada desde variables de entorno."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Base de datos ──────────────────────────────────────────
    DATABASE_URL: str

    # ── Aplicación ─────────────────────────────────────────────
    APP_TITLE: str = "Plataforma Inteligente de Emergencias Vehiculares"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"

    # ── Seguridad / JWT ────────────────────────────────────────
    SECRET_KEY: str = "cambiar-en-produccion"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60


@lru_cache
def get_settings() -> Settings:
    """Singleton cacheado de la configuración."""
    return Settings()
