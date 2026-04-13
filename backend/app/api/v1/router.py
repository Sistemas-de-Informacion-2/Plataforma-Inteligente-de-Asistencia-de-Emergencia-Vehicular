# backend/app/api/v1/router.py
"""
Router principal de la API v1.
Registra todos los sub-routers con sus prefijos y tags.

Nota de seguridad:
- /talleres NO tiene Depends global porque /talleres/onboarding es público.
  La seguridad se maneja endpoint por endpoint dentro de talleres.py.
- Los demás routers protegidos usan Depends(get_current_user) a nivel global
  o a nivel de endpoint según corresponda.
"""

from fastapi import APIRouter, Depends

from app.api.v1.endpoints import usuarios
from app.api.v1.endpoints import talleres
from app.api.v1.endpoints import solicitudes
from app.api.v1.endpoints import ordenes
from app.api.v1.endpoints import auth
from app.api.v1.endpoints import notificaciones_ws
from app.api.v1.endpoints import empleados
from app.api.v1.endpoints import servicios
from app.api.v1.endpoints import vehiculos
from app.api.v1.endpoints import incidentes
from app.api.deps import get_current_user

api_router = APIRouter()

# ── Rutas públicas ────────────────────────────────────────────
api_router.include_router(auth.router, prefix="/auth", tags=["Autenticación"])
api_router.include_router(usuarios.router, prefix="/usuarios", tags=["Usuarios"])
api_router.include_router(notificaciones_ws.router, prefix="/ws/notificaciones", tags=["WebSockets"])

# ── Talleres: seguridad a nivel de endpoint (onboarding es público) ─
api_router.include_router(
    talleres.router,
    prefix="/talleres",
    tags=["Talleres y Sucursales"],
)

# ── Empleados: protegidos por JWT a nivel de endpoint ─────────
api_router.include_router(
    empleados.router,
    prefix="/empleados",
    tags=["Empleados (Técnicos)"],
)

# ── Servicios: protegidos por JWT a nivel de endpoint ─────────
api_router.include_router(
    servicios.router,
    prefix="/servicios",
    tags=["Servicios y Especialidades"],
)

# ── Rutas protegidas por JWT (dependencia global) ─────────────
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
api_router.include_router(
    vehiculos.router,
    prefix="/vehiculos",
    tags=["Vehículos del Cliente"],
    dependencies=[Depends(get_current_user)]
)
api_router.include_router(
    incidentes.router,
    prefix="/incidentes",
    tags=["Reporte de Incidentes"],
    dependencies=[Depends(get_current_user)]
)
