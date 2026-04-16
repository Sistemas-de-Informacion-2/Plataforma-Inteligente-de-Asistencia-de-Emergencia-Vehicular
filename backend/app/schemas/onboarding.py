# backend/app/schemas/onboarding.py
"""
Schemas Pydantic: Onboarding Todo-en-Uno para Admin de Taller.
Transacción atómica que crea: Usuario → Rol → Admin → Taller → Sucursal.
"""
from pydantic import BaseModel, ConfigDict, Field

class TallerOnboardingRequest(BaseModel):
    """Datos para el registro completo de un Admin de Taller."""
    # ── Datos del Usuario ─────────────────────────────────────
    nombre: str = Field(..., min_length=1, max_length=100)
    email: str = Field(..., max_length=150)
    password: str = Field(..., min_length=6, max_length=255)
    ci: str = Field(..., min_length=1, max_length=20)
    telefono: str | None = Field(None, max_length=20)

    # ── Datos del Taller ──────────────────────────────────────
    nombre_taller: str = Field(..., min_length=1, max_length=150)
    descripcion_taller: str | None = None

    # ── Datos de la Primera Sucursal ──────────────────────────
    nombre_sucursal: str = Field(..., min_length=1, max_length=150)
    direccion_sucursal: str | None = Field(None, max_length=300)
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)
    telefono_sucursal: str | None = Field(None, max_length=20)


class TallerOnboardingResponse(BaseModel):
    """Respuesta del onboarding con los IDs creados y token JWT."""
    model_config = ConfigDict(from_attributes=True)
    usuario_id: int
    admin_id: int
    taller_id: int
    sucursal_id: int
    access_token: str
    token_type: str = "bearer"
    mensaje: str = "Onboarding completado exitosamente"
