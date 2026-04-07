from fastapi import APIRouter

from app.api.v1.endpoints import usuarios
from app.api.v1.endpoints import talleres
from app.api.v1.endpoints import solicitudes
from app.api.v1.endpoints import ordenes

api_router = APIRouter()

api_router.include_router(usuarios.router, prefix="/usuarios", tags=["Usuarios"])
api_router.include_router(talleres.router, prefix="/talleres", tags=["Talleres y Sucursales"])
api_router.include_router(solicitudes.router, prefix="/solicitudes", tags=["Emergencias y Asignaciones"])
api_router.include_router(ordenes.router, prefix="/ordenes", tags=["Ordenes de Trabajo y Pagos"])
