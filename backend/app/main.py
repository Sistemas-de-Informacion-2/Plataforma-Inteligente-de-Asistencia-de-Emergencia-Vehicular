# backend/app/main.py
"""
Punto de entrada principal de la aplicación FastAPI.
Configura CORS, lifespan y routers.
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
import traceback
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
# Orígenes dinámicos desde variable de entorno ALLOWED_ORIGINS
origins = [o.strip() for o in settings.ALLOWED_ORIGINS.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Registrar Routers ─────────────────────────────────────────
app.include_router(api_router, prefix=settings.API_V1_PREFIX)

import os
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# ── Health Check ──────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def health_check():
    """Endpoint de verificación — confirma que el backend está vivo."""
    return {
        "status": "ok",
        "mensaje": "¡El backend está vivo y listo para recibir emergencias! 🚗",
        "version": "1.0.0",
    }