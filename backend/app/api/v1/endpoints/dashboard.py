# backend/app/api/v1/endpoints/dashboard.py
"""
Endpoints del Dashboard KPI.
Todos requieren JWT válido. La vista es:
  - SUPER_ADMIN  → datos globales (taller_id = None)
  - ADMIN_TALLER → solo datos de su propio taller
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.admin import Admin
from app.models.taller import Taller
from app.models.usuario import Usuario
from app.schemas.dashboard import (
    KPI1TiempoEspera,
    KPI2SucursalAceptacion,
    KPI3TiempoAsignacion,
    KPI4TiempoLlegada,
    KPI5IncidenciaItem,
    KPI6TallerEficiente,
    KPI7MapaCalorItem,
    KPI8CanceladosMes,
    KPI9PuntualidadItem,
    KPI10PrecisionCostoItem,
    KPI11MecanicoRankingItem,
)
from app.services.dashboard_service import DashboardService

router = APIRouter()

# ── Parámetros comunes ────────────────────────────────────────────────────────

_FECHA_INICIO = Query(
    None,
    description="Filtro de fecha de inicio (ISO 8601). Ej: 2026-01-01T00:00:00",
)
_FECHA_FIN = Query(
    None,
    description="Filtro de fecha de fin (ISO 8601). Ej: 2026-12-31T23:59:59",
)


# ── Dependencia B2B ───────────────────────────────────────────────────────────

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
        detail="Solo SUPER_ADMIN y ADMIN_TALLER pueden acceder al dashboard.",
    )


# ── KPI 1 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi1-tiempo-espera",
    response_model=KPI1TiempoEspera,
    summary="[SA / TA] KPI 1 — El Pulso del Negocio (Tiempo Total de Resolución)",
    description=(
        "**Perspectiva de Negocio:** Mide la promesa de valor principal de la plataforma. "
        "Si este número es muy alto, los clientes se frustrarán y desinstalarán la app. "
        "Para el SA indica la salud general del servicio; para el TA indica qué tan rápidos son sus equipos desde que suena la alerta hasta que cobran."
    ),
)
async def kpi1_tiempo_espera(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> KPI1TiempoEspera:
    data = await DashboardService(db).kpi1_tiempo_espera(fecha_inicio, fecha_fin, taller_id)
    return KPI1TiempoEspera(**data)


# ── KPI 2 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi2-tasa-aceptacion",
    response_model=list[KPI2SucursalAceptacion],
    summary="[SA / TA] KPI 2 — Índice de Responsividad (Tasa de Conversión de SOS)",
    description=(
        "**Perspectiva de Negocio:** ¿Estamos perdiendo oportunidades de hacer dinero? "
        "Para el SA, revela qué talleres son 'fantasmas' en la app y no aportan valor. "
        "Para el TA, es una herramienta de control laboral: indica si sus mecánicos están ignorando las alertas de clientes potenciales."
    ),
)
async def kpi2_tasa_aceptacion(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> list[KPI2SucursalAceptacion]:
    rows = await DashboardService(db).kpi2_tasa_aceptacion(fecha_inicio, fecha_fin, taller_id)
    return [KPI2SucursalAceptacion(**r) for r in rows]


# ── KPI 3 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi3-tiempo-asignacion",
    response_model=KPI3TiempoAsignacion,
    summary="[SA / TA] KPI 3 — Fricción del Marketplace (Tiempo de Match)",
    description=(
        "**Perspectiva de Negocio:** Mide la agilidad del mercado libre. ¿Cuánto tarda un cliente en recibir y aceptar una oferta? "
        "Tiempos largos indican que no hay suficientes mecánicos ofertando rápido o que los precios espantan al cliente."
    ),
)
async def kpi3_tiempo_asignacion(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> KPI3TiempoAsignacion:
    data = await DashboardService(db).kpi3_tiempo_asignacion(fecha_inicio, fecha_fin, taller_id)
    return KPI3TiempoAsignacion(**data)


# ── KPI 4 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi4-tiempo-llegada",
    response_model=KPI4TiempoLlegada,
    summary="[SA / TA] KPI 4 — Brecha de Expectativa (Promesa vs Realidad)",
    description=(
        "**Perspectiva de Negocio:** ¿Mentimos a nuestros clientes? Este KPI compara el ETA que le vendimos al cliente "
        "contra lo que realmente tardó el mecánico en llegar. Un delta positivo alto destruye la confianza en la plataforma y genera malas reseñas."
    ),
)
async def kpi4_tiempo_llegada(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> KPI4TiempoLlegada:
    data = await DashboardService(db).kpi4_tiempo_llegada(fecha_inicio, fecha_fin, taller_id)
    return KPI4TiempoLlegada(**data)


# ── KPI 5 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi5-tipos-incidencia",
    response_model=list[KPI5IncidenciaItem],
    summary="[SA / TA] KPI 5 — Inteligencia de Mercado (Distribución de Demanda)",
    description=(
        "**Perspectiva de Negocio:** ¿De qué sufre la ciudad? "
        "Para el SA, dicta alianzas estratégicas (ej. si el 60% son baterías, buscar convenios con importadoras de baterías). "
        "Para el TA, dicta el inventario: qué repuestos tener listos en los vehículos de auxilio para facturar más."
    ),
)
async def kpi5_tipos_incidencia(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> list[KPI5IncidenciaItem]:
    rows = await DashboardService(db).kpi5_tipos_incidencia(fecha_inicio, fecha_fin, taller_id)
    return [KPI5IncidenciaItem(**r) for r in rows]


# ── KPI 6 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi6-ranking-talleres",
    response_model=list[KPI6TallerEficiente],
    summary="[SA] KPI 6 — Top Performers (Ranking Global de Calidad)",
    description=(
        "**Perspectiva de Negocio:** El termómetro de los socios comerciales. "
        "Cruza reseñas, puntualidad y tasa de abandono para decirle al dueño de la plataforma qué talleres merecen más visibilidad "
        "y cuáles deben ser penalizados o expulsados para cuidar la marca."
    ),
)
async def kpi6_ranking_talleres(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> list[KPI6TallerEficiente]:
    rows = await DashboardService(db).kpi6_ranking_talleres(fecha_inicio, fecha_fin, taller_id)
    return [KPI6TallerEficiente(**r) for r in rows]


# ── KPI 7 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi7-mapa-calor",
    response_model=list[KPI7MapaCalorItem],
    summary="[SA] KPI 7 — Expansión Territorial (Zonas Calientes de Demanda)",
    description=(
        "**Perspectiva de Negocio:** Identifica minas de oro geográficas. "
        "Muestra dónde se concentran las emergencias (ej. anillos principales, avenidas clave). "
        "Vital para dirigir la fuerza de ventas y afiliar talleres exactamente donde la demanda es más alta y la oferta no da abasto."
    ),
)
async def kpi7_mapa_calor(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> list[KPI7MapaCalorItem]:
    rows = await DashboardService(db).kpi7_mapa_calor(fecha_inicio, fecha_fin, taller_id)
    return [KPI7MapaCalorItem(**r) for r in rows]


# ── KPI 8 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi8-tasa-cancelados",
    response_model=list[KPI8CanceladosMes],
    summary="[SA / TA] KPI 8 — Fuga de Capital (Tasa de Abandono)",
    description=(
        "**Perspectiva de Negocio:** Dinero que se esfumó. "
        "Mide la frustración del usuario. Una tasa de cancelados creciente es una alerta roja de que el servicio es muy caro, "
        "muy lento, o la UX de la aplicación está fallando."
    ),
)
async def kpi8_tasa_cancelados(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> list[KPI8CanceladosMes]:
    rows = await DashboardService(db).kpi8_tasa_cancelados(fecha_inicio, fecha_fin, taller_id)
    return [KPI8CanceladosMes(**r) for r in rows]


# ── KPI 9 ─────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi9-puntualidad",
    response_model=list[KPI9PuntualidadItem],
    summary="[TA] KPI 9 — Auditoría Operativa (Cumplimiento de Empleados)",
    description=(
        "**Perspectiva de Negocio:** Control de personal en campo. "
        "Segmenta los auxilios en A TIEMPO vs ATRASADO. Permite al dueño del taller evaluar el desempeño real de sus mecánicos "
        "y detectar quiénes están afectando la reputación de la sucursal."
    ),
)
async def kpi9_puntualidad(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> list[KPI9PuntualidadItem]:
    rows = await DashboardService(db).kpi9_puntualidad(fecha_inicio, fecha_fin, taller_id)
    return [KPI9PuntualidadItem(**r) for r in rows]


# ── KPI 10 ────────────────────────────────────────────────────────────────────

@router.get(
    "/kpi10-precision-costos",
    response_model=list[KPI10PrecisionCostoItem],
    summary="[SA / TA] KPI 10 — Integridad Financiera (Desviación de Precios)",
    description=(
        "**Perspectiva de Negocio:** ¿Estamos cobrando lo justo? "
        "Compara la estimación inteligente de Gemini contra lo que el mecánico metió en la factura final. "
        "Desviaciones altas indican que la IA necesita reentrenamiento (para el SA) o que el mecánico está inflando precios al cliente (para el TA)."
    ),
)
async def kpi10_precision_costos(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: Optional[int] = Depends(_resolve_taller_id),
    db: AsyncSession = Depends(get_db),
) -> list[KPI10PrecisionCostoItem]:
    rows = await DashboardService(db).kpi10_precision_costos(fecha_inicio, fecha_fin, taller_id)
    return [KPI10PrecisionCostoItem(**r) for r in rows]


# ── KPI 11 — Exclusivo ADMIN_TALLER ──────────────────────────────────────────

async def _require_admin_taller_id(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> int:
    """
    Dependencia exclusiva para ADMIN_TALLER.
    Devuelve el taller_id del admin autenticado.
    SUPER_ADMIN y otros roles reciben 403.
    """
    roles = {r.rol.nombre for r in current_user.roles}

    if "ADMIN_TALLER" not in roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Este KPI es exclusivo para administradores de taller (ADMIN_TALLER).",
        )

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


@router.get(
    "/kpi11-ranking-mecanicos",
    response_model=list[KPI11MecanicoRankingItem],
    summary="[TA] KPI 11 — Tu Capital Humano (Ranking de Mecánicos)",
    description=(
        "**Exclusivo ADMIN_TALLER.** "
        "Ranking de los mecánicos de tu taller ordenado por asignaciones COMPLETADAS. "
        "Incluye el tiempo promedio real de llegada, el ETA prometido y el delta entre ambos "
        "(positivo = llegan tarde, negativo = llegan antes de lo prometido). "
        "Úsalo para detectar a tu estrella y a quien necesita seguimiento."
    ),
)
async def kpi11_ranking_mecanicos(
    fecha_inicio: Optional[datetime] = _FECHA_INICIO,
    fecha_fin: Optional[datetime] = _FECHA_FIN,
    taller_id: int = Depends(_require_admin_taller_id),
    db: AsyncSession = Depends(get_db),
) -> list[KPI11MecanicoRankingItem]:
    rows = await DashboardService(db).kpi11_ranking_mecanicos(taller_id, fecha_inicio, fecha_fin)
    return [KPI11MecanicoRankingItem(**r) for r in rows]