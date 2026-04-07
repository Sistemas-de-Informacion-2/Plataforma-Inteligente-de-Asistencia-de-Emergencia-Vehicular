"""
Servicio: Asignación Inteligente.

Motor de selección de taller/técnico basado en:
  1. Proximidad geográfica (PostGIS ST_DWithin)
  2. Compatibilidad de servicios (tipo de problema)
  3. Disponibilidad de técnicos
  4. Prioridad del incidente
"""

import logging
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.asignacion import Asignacion, EstadoAsignacion
from app.models.taller import Sucursal
from app.models.servicio import SucursalServicio, Servicio
from app.models.empleado import Empleado
from app.repositories.taller_repository import SucursalRepository
from app.repositories.empleado_repository import EmpleadoRepository
from app.repositories.asignacion_repository import AsignacionRepository
from app.schemas.asignacion import AsignacionCreate

logger = logging.getLogger(__name__)


class AsignacionService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.sucursal_repo = SucursalRepository(session)
        self.empleado_repo = EmpleadoRepository(session)
        self.asignacion_repo = AsignacionRepository(session)

    async def buscar_mejor_taller(
        self,
        solicitud_id: int,
        latitud_incidente: float,
        longitud_incidente: float,
        tipo_problema: str,
        *,
        radio_km: float = 15.0,
        max_candidatos: int = 10,
    ) -> dict[str, Any]:
        """
        Algoritmo de asignación inteligente. Pasos:

        1. Buscar sucursales cercanas al incidente (PostGIS)
        2. Filtrar por compatibilidad de servicios
        3. Verificar disponibilidad de técnicos
        4. Rankear candidatos y seleccionar el mejor
        5. Crear la asignación

        Args:
            solicitud_id:       ID de la solicitud de emergencia
            latitud_incidente:  Latitud del incidente
            longitud_incidente: Longitud del incidente
            tipo_problema:      Tipo de problema detectado (ej: "Auxilio eléctrico")
            radio_km:           Radio de búsqueda en km
            max_candidatos:     Máximo sucursales candidatas

        Returns:
            {
                "asignacion": Asignacion | None,
                "candidatos": list[dict],
                "seleccionado": dict | None,
                "motivo": str,
            }
        """
        resultado = {
            "asignacion": None,
            "candidatos": [],
            "seleccionado": None,
            "motivo": "",
        }

        # ── Paso 1: Sucursales cercanas ───────────────────────
        logger.info(
            f"[Asignación] Buscando sucursales en radio de {radio_km}km "
            f"desde ({latitud_incidente}, {longitud_incidente})"
        )

        sucursales_cercanas = await self.sucursal_repo.buscar_cercanas(
            latitud_incidente,
            longitud_incidente,
            radio_km=radio_km,
            limit=max_candidatos,
        )

        if not sucursales_cercanas:
            resultado["motivo"] = (
                f"No se encontraron sucursales en un radio de {radio_km}km"
            )
            logger.warning(f"[Asignación] {resultado['motivo']}")
            return resultado

        logger.info(
            f"[Asignación] {len(sucursales_cercanas)} sucursales encontradas"
        )

        # ── Paso 2: Filtrar por servicio compatible ───────────
        candidatos_con_servicio = []

        for item in sucursales_cercanas:
            sucursal: Sucursal = item["sucursal"]
            distancia_km: float = item["distancia_km"]

            # Verificar si la sucursal ofrece el servicio requerido
            tiene_servicio = await self._sucursal_ofrece_servicio(
                sucursal.id, tipo_problema
            )

            candidato = {
                "sucursal_id": sucursal.id,
                "sucursal_nombre": sucursal.nombre,
                "taller_id": sucursal.taller_id,
                "distancia_km": distancia_km,
                "tiene_servicio": tiene_servicio,
                "tecnicos_disponibles": [],
                "score": 0.0,
            }

            if tiene_servicio:
                candidatos_con_servicio.append(candidato)
            else:
                # Incluir igualmente pero con score penalty
                candidato["score"] = -10.0
                candidatos_con_servicio.append(candidato)

        # ── Paso 3: Verificar técnicos disponibles ────────────
        for candidato in candidatos_con_servicio:
            tecnicos = await self.empleado_repo.get_disponibles(
                sucursal_id=candidato["sucursal_id"],
            )
            candidato["tecnicos_disponibles"] = [
                {"id": t.id, "especialidad": t.especialidad}
                for t in tecnicos
            ]

        # ── Paso 4: Calcular score y rankear ──────────────────
        for candidato in candidatos_con_servicio:
            candidato["score"] = self._calcular_score(candidato)

        # Ordenar por score descendente
        candidatos_con_servicio.sort(key=lambda c: c["score"], reverse=True)
        resultado["candidatos"] = candidatos_con_servicio

        # ── Paso 5: Seleccionar el mejor y crear asignación ──
        mejor = self._seleccionar_mejor(candidatos_con_servicio)

        if mejor is None:
            resultado["motivo"] = (
                "Ninguna sucursal cercana tiene técnicos disponibles "
                "con el servicio requerido"
            )
            logger.warning(f"[Asignación] {resultado['motivo']}")
            return resultado

        resultado["seleccionado"] = mejor

        # Elegir el primer técnico disponible de la sucursal seleccionada
        tecnico_id = None
        if mejor["tecnicos_disponibles"]:
            tecnico_id = mejor["tecnicos_disponibles"][0]["id"]

        # Calcular tiempo estimado de llegada (aprox 3 min/km)
        eta_minutos = max(5, round(mejor["distancia_km"] * 3))

        # Crear la asignación en BD
        asignacion_data = AsignacionCreate(
            solicitud_id=solicitud_id,
            empleado_id=tecnico_id,
            sucursal_id=mejor["sucursal_id"],
            estado=EstadoAsignacion.PENDIENTE,
            tiempo_estimado_llegada=eta_minutos,
        )

        asignacion = await self.asignacion_repo.create(
            asignacion_data.model_dump()
        )

        resultado["asignacion"] = asignacion
        resultado["motivo"] = (
            f"Asignado a '{mejor['sucursal_nombre']}' "
            f"({mejor['distancia_km']}km, ETA ~{eta_minutos}min)"
        )
        logger.info(f"[Asignación] {resultado['motivo']}")

        return resultado

    # ── Gestión de asignaciones existentes ────────────────────

    async def aceptar_asignacion(self, asignacion_id: int) -> Asignacion | None:
        return await self.asignacion_repo.actualizar_estado(
            asignacion_id, EstadoAsignacion.ACEPTADA
        )

    async def rechazar_asignacion(self, asignacion_id: int) -> Asignacion | None:
        return await self.asignacion_repo.actualizar_estado(
            asignacion_id, EstadoAsignacion.RECHAZADA
        )

    async def marcar_en_camino(self, asignacion_id: int) -> Asignacion | None:
        return await self.asignacion_repo.actualizar_estado(
            asignacion_id, EstadoAsignacion.EN_CAMINO
        )

    async def marcar_en_sitio(self, asignacion_id: int) -> Asignacion | None:
        return await self.asignacion_repo.actualizar_estado(
            asignacion_id, EstadoAsignacion.EN_SITIO
        )

    async def completar_asignacion(self, asignacion_id: int) -> Asignacion | None:
        return await self.asignacion_repo.actualizar_estado(
            asignacion_id, EstadoAsignacion.COMPLETADA
        )

    async def obtener_asignaciones_solicitud(
        self, solicitud_id: int
    ) -> list[Asignacion]:
        return list(
            await self.asignacion_repo.get_by_solicitud(solicitud_id)
        )

    async def obtener_asignacion_activa(
        self, solicitud_id: int
    ) -> Asignacion | None:
        return await self.asignacion_repo.get_activa_de_solicitud(solicitud_id)

    # ═══════════════════════════════════════════════════════════
    #  Métodos internos del algoritmo
    # ═══════════════════════════════════════════════════════════

    async def _sucursal_ofrece_servicio(
        self, sucursal_id: int, tipo_problema: str
    ) -> bool:
        """Verifica si una sucursal tiene un servicio que coincida con el problema."""
        stmt = (
            select(SucursalServicio)
            .join(Servicio, SucursalServicio.servicio_id == Servicio.id)
            .where(
                SucursalServicio.sucursal_id == sucursal_id,
                Servicio.nombre.ilike(f"%{tipo_problema}%"),
            )
        )
        result = await self.session.execute(stmt)
        return result.first() is not None

    def _calcular_score(self, candidato: dict) -> float:
        """
        Calcula un puntaje para cada sucursal candidata.

        Factores (mayor = mejor):
          - Distancia: -2 puntos por km (más cerca = mejor)
          - Servicio: +20 si tiene el servicio requerido
          - Técnicos: +5 por cada técnico disponible (máx +15)
        """
        score = candidato.get("score", 0.0)

        # Penalizar distancia: -2pts por km
        score -= candidato["distancia_km"] * 2

        # Bonificar por tener el servicio requerido
        if candidato["tiene_servicio"]:
            score += 20.0

        # Bonificar por técnicos disponibles (máx 3 cuentan)
        num_tecnicos = min(len(candidato["tecnicos_disponibles"]), 3)
        score += num_tecnicos * 5.0

        return round(score, 2)

    def _seleccionar_mejor(
        self, candidatos: list[dict]
    ) -> dict | None:
        """
        Selecciona el mejor candidato:
        Debe tener al menos un técnico disponible.
        """
        for candidato in candidatos:
            if candidato["tecnicos_disponibles"]:
                return candidato
        return None
