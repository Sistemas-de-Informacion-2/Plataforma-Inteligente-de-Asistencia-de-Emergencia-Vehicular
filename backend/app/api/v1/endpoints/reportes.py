# backend/app/api/v1/endpoints/reportes.py
"""
Endpoints del Módulo de Reportes Avanzados.

Seguridad multi-tenant idéntica al dashboard:
  - SUPER_ADMIN  → taller_id = None  (vista global)
  - ADMIN_TALLER → taller_id = <su taller>
  - Otros roles  → 403 Forbidden

Tres flujos:
  GET  /reportes/predefinido/{kpi_id}  → exporta un KPI existente
  POST /reportes/dinamico              → reporte por entidad + columnas + filtros
  POST /reportes/ia                    → reporte desde lenguaje natural (Gemini)
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.admin import Admin
from app.models.taller import Taller
from app.models.usuario import Usuario
from app.schemas.reportes import ReporteIARequest, ReporteManualRequest
from app.services.reporte_service import ReporteService

router = APIRouter()

# ── Tipos MIME por extensión ──────────────────────────────────────────────────

_MEDIA_TYPES: dict[str, str] = {
    "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "csv":  "text/csv; charset=utf-8-sig",
    "pdf":  "application/pdf",
}

# ── Parámetros de fecha comunes ───────────────────────────────────────────────

_FECHA_INICIO = Query(None, description="Filtro de fecha inicio (ISO 8601). Ej: 2026-01-01T00:00:00")
_FECHA_FIN    = Query(None, description="Filtro de fecha fin (ISO 8601). Ej: 2026-12-31T23:59:59")


# ── Dependencia multi-tenant (replicada del dashboard) ───────────────────────

async def _resolve_taller_id(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Optional[int]:
    """
    Resuelve el taller_id según el rol del usuario autenticado.
    SUPER_ADMIN → None (vista global).
    ADMIN_TALLER → id del taller que administra.
    Otros roles → 403.
    """
    roles = {r.rol.nombre for r in current_user.roles}

    if "SUPER_ADMIN" in roles:
        return None

    if "ADMIN_TALLER" in roles:
        result = await db.execute(
            select(Taller.id)
            .join(Admin, Admin.id == Taller.admin_id)
            .where(Admin.usuario_id == current_user.id)
            .limit(1)
        )
        taller_id = result.scalar_one_or_none()
        if taller_id is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes un taller asignado a tu perfil de administrador.",
            )
        return taller_id

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Solo SUPER_ADMIN y ADMIN_TALLER pueden generar reportes.",
    )


# ── Utilidad: construir StreamingResponse ────────────────────────────────────

def _streaming(buf, ext: str, nombre: str) -> StreamingResponse:
    return StreamingResponse(
        buf,
        media_type=_MEDIA_TYPES[ext],
        headers={"Content-Disposition": f'attachment; filename="{nombre}"'},
    )


# ── Endpoint 1: Exportar KPI Predefinido ─────────────────────────────────────

@router.get(
    "/predefinido/{kpi_id}",
    summary="[SA / TA] Exportar un KPI del dashboard en Excel, CSV o PDF",
    description=(
        "Exporta cualquiera de los 11 KPIs del dashboard analítico en el formato "
        "solicitado (xlsx, csv o pdf). "
        "**SUPER_ADMIN** obtiene datos globales; **ADMIN_TALLER** solo datos de su taller. "
        "El **KPI 11** (ranking de mecánicos) es exclusivo para ADMIN_TALLER."
    ),
)
async def exportar_predefinido(
    kpi_id: int,
    formato: str = Query("xlsx", description="Formato de exportación: xlsx, csv, pdf"),
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    try:
        buf, ext, nombre = await ReporteService(db).exportar_predefinido(
            kpi_id=kpi_id,
            formato=formato.lower().strip(),
            taller_id=taller_id,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    return _streaming(buf, ext, nombre)


# ── Endpoint 2: Reporte Dinámico ──────────────────────────────────────────────

@router.post(
    "/dinamico",
    summary="[SA / TA] Reporte personalizado por entidad y columnas",
    description=(
        "Genera un reporte eligiendo libremente la entidad, columnas y filtros "
        "dentro del whitelist de seguridad aprobado. "
        "Entidades disponibles: **SOLICITUDES**, **MECANICOS**, **DIAGNOSTICOS**, "
        "**ASIGNACIONES**, **PUJAS**. "
        "El filtro multi-tenant (taller_id) se aplica automáticamente según el rol. "
        "\n\n**Ejemplo de body:**\n"
        "```json\n"
        "{\n"
        '  "entidad": "SOLICITUDES",\n'
        '  "columnas": ["id", "estado", "fecha_creacion"],\n'
        '  "filtros": {"estado": "CANCELADO"},\n'
        '  "fecha_inicio": "2026-01-01T00:00:00",\n'
        '  "formato": "xlsx"\n'
        "}\n"
        "```"
    ),
)
async def reporte_dinamico(
    request: ReporteManualRequest,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    try:
        buf, ext, nombre = await ReporteService(db).generar_reporte_dinamico(
            tabla_base=request.tabla_base,
            tablas_relacionadas=request.tablas_relacionadas,
            columnas=request.columnas,
            filtros=request.filtros,
            fecha_inicio=request.fecha_inicio,
            fecha_fin=request.fecha_fin,
            formato=request.formato,
            taller_id=taller_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    return _streaming(buf, ext, nombre)


# ── Endpoint 3: Reporte desde Lenguaje Natural (IA) ──────────────────────────

@router.post(
    "/ia",
    summary="[SA / TA] Reporte generado desde lenguaje natural con Gemini",
    description=(
        "Interpreta un prompt en lenguaje natural con Google Gemini para determinar "
        "entidad, columnas y filtros, luego genera y descarga el reporte directamente. "
        "El filtro multi-tenant se aplica automáticamente según el rol. "
        "\n\n**Ejemplos de prompts:**\n"
        "- *'Dame todas las solicitudes canceladas de enero 2026 en Excel'*\n"
        "- *'Exporta los mecánicos disponibles en PDF'*\n"
        "- *'Necesito las pujas aceptadas del último trimestre en CSV'*"
    ),
)
async def reporte_ia(
    request: ReporteIARequest,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    svc = ReporteService(db)

    # ── Paso 1: Gemini interpreta el prompt ───────────────────────────────────
    try:
        params = await svc.interpretar_prompt_ia(
            prompt=request.prompt,
            formato_override=request.formato,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"No se pudo interpretar el prompt: {exc}",
        )

    # ── Paso 1b: Inyectar defaults — Gemini a veces omite claves opcionales ──
    params.setdefault("tablas_relacionadas", [])
    params.setdefault("columnas", [])
    params.setdefault("filtros", {})
    params.setdefault("fecha_inicio", None)
    params.setdefault("fecha_fin", None)

    # ── Paso 2: Parsear fechas que devuelve la IA (pueden venir como string) ──
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None
    for campo, destino in [("fecha_inicio", "fecha_inicio"), ("fecha_fin", "fecha_fin")]:
        raw = params.get(campo)
        if raw:
            try:
                val = datetime.fromisoformat(str(raw))
                if campo == "fecha_inicio":
                    fecha_inicio = val
                else:
                    fecha_fin = val
            except (ValueError, TypeError):
                pass  # ignorar fechas malformadas de la IA

    # ── Paso 3: Generar el archivo con los parámetros validados ───────────────
    try:
        buf, ext, nombre = await svc.generar_reporte_dinamico(
            tabla_base=params["tabla_base"],
            tablas_relacionadas=params.get("tablas_relacionadas", []),
            columnas=params.get("columnas", []),
            filtros=params.get("filtros", {}),
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
            formato=params.get("formato", request.formato),
            taller_id=taller_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))

    return _streaming(buf, ext, nombre)
