from fastapi import APIRouter, Depends

from app.api.v1.endpoints import usuarios
from app.api.v1.endpoints import talleres
from app.api.v1.endpoints import solicitudes
from app.api.v1.endpoints import ordenes
from app.api.v1.endpoints import auth
from app.api.v1.endpoints import notificaciones_ws
from app.api.deps import get_current_user

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Autenticación"])
api_router.include_router(usuarios.router, prefix="/usuarios", tags=["Usuarios"])
api_router.include_router(notificaciones_ws.router, prefix="/ws/notificaciones", tags=["WebSockets"])

# Rutas protegidas por JWT
api_router.include_router(
    talleres.router, 
    prefix="/talleres", 
    tags=["Talleres y Sucursales"], 
    dependencies=[Depends(get_current_user)]
)
api_router.include_router(
    solicitudes.router, 
    prefix="/solicitudes", 
    tags=["Emergencias y Asignaciones"], 
    dependencies=[Depends(get_current_user)]
)
api_router.include_router(
    ordenes.router, 
    prefix="/ordenes", 
    tags=["Ordenes de Trabajo y Pagos"], 
    dependencies=[Depends(get_current_user)]
)
