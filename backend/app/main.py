"""
Punto de entrada principal de la aplicación FastAPI.
Configura CORS, lifespan y routers.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings

settings = get_settings()


# ── Lifespan: inicialización y cierre ──────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Evento de inicio: importa modelos para registrar metadata.
    Las tablas se gestionan con Alembic (no create_all).
    """
    # Importar modelos para que SQLAlchemy registre la metadata
    import app.models  # noqa: F401
    yield
    # Aquí se puede cerrar conexiones, limpiar recursos, etc.


# ── Crear la aplicación ───────────────────────────────────────
app = FastAPI(
    title=settings.APP_TITLE,
    description="API para la Plataforma Inteligente de Atención de Emergencias Vehiculares",
    version="1.0.0",
    lifespan=lifespan,
)


# ── CORS ──────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:4200",   # Angular frontend
        "http://localhost:3000",   # Alternativo
        "*",                       # Dev: permitir todo (restringir en prod)
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Registrar Routers ─────────────────────────────────────────
app.include_router(api_router, prefix=settings.API_V1_PREFIX)


# ── Health Check ──────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def health_check():
    """Endpoint de verificación — confirma que el backend está vivo."""
    return {
        "status": "ok",
        "mensaje": "¡El backend está vivo y listo para recibir emergencias! 🚗",
        "version": "1.0.0",
    }