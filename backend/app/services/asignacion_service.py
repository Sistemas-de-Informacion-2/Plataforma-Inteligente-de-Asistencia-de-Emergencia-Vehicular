# backend/app/services/asignacion_service.py
"""
Servicio: Asignación Inteligente.

Motor de selección de taller/técnico basado en:
  1. Proximidad geográfica (PostGIS ST_DWithin)
  2. Compatibilidad de servicios (nombres exactos del catálogo plano)
  3. Disponibilidad de técnicos
  4. Reputación de la sucursal (rating promedio de reseñas)
"""

import logging
from typing import Any

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asignacion import Asignacion, EstadoAsignacion
from app.models.taller import Sucursal, Taller
from app.models.servicio import SucursalServicio, Servicio
from app.models.empleado import Empleado
from app.models.resena import ResenaForo
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

    async def buscar_sucursales_aptas(
        self,
        latitud_incidente: float,
        longitud_incidente: float,
        servicios_requeridos: list[str],
        *,
        radio_km: float = 15.0,
        max_candidatos: int = 10,
    ) -> list[dict[str, Any]]:
        """
        Busca y rankea sucursales aptas SIN crear asignación.
        Usado en Fase 1 del flujo 'Uber para Mecánicos Inverso':
        el cliente recibe la lista y elige.

        Args:
            servicios_requeridos: Lista de nombres EXACTOS de servicios
                                 devueltos por la IA (del catálogo plano).

        Returns:
            Lista de candidatos ordenados por score descendente.
            Cada candidato contiene: sucursal_id, nombre, taller_nombre,
            distancia_km, tiene_servicio, tecnicos_disponibles, score,
            rating, eta_minutos.
        """
        logger.info(
            f"[Recomendación] Buscando sucursales aptas en radio de {radio_km}km "
            f"desde ({latitud_incidente}, {longitud_incidente}) "
            f"para servicios: {servicios_requeridos}"
        )

        # ── Paso 1: Sucursales cercanas (PostGIS) ─────────────
        sucursales_cercanas = await self.sucursal_repo.buscar_cercanas(
            latitud_incidente,
            longitud_incidente,
            radio_km=radio_km,
            limit=max_candidatos,
        )

        if not sucursales_cercanas:
            logger.warning(f"[Recomendación] No se encontraron sucursales en radio de {radio_km}km")
            return []

        logger.info(f"[Recomendación] {len(sucursales_cercanas)} sucursales encontradas")

        # Extraer IDs de sucursales cercanas para consultas batch
        ids_cercanas = [item["sucursal"].id for item in sucursales_cercanas]

        # ── Paso 2: Consulta batch de servicios compatibles ───
        # Una sola query para saber qué sucursales ofrecen al menos
        # uno de los servicios requeridos por la IA.
        servicios_por_sucursal = await self._obtener_servicios_compatibles_batch(
            ids_cercanas, servicios_requeridos
        )

        # ── Paso 3: Consulta batch de ratings ─────────────────
        # Evita N+1: un solo AVG agrupado por sucursal_id.
        ratings_por_sucursal = await self._obtener_ratings_batch(ids_cercanas)

        # ── Paso 4: Construir candidatos ──────────────────────
        candidatos: list[dict[str, Any]] = []
        for item in sucursales_cercanas:
            sucursal: Sucursal = item["sucursal"]
            distancia_km: float = item["distancia_km"]

            tiene_servicio = sucursal.id in servicios_por_sucursal
            rating_data = ratings_por_sucursal.get(sucursal.id, {"rating": 0.0, "rating_count": 0})
            rating = rating_data["rating"]
            rating_count = rating_data["rating_count"]

            # Obtener nombre del taller padre
            taller_nombre = ""
            if sucursal.taller_id:
                taller = await self.session.get(Taller, sucursal.taller_id)
                taller_nombre = taller.nombre if taller else ""

            candidato = {
                "sucursal_id": sucursal.id,
                "sucursal_nombre": sucursal.nombre,
                "sucursal_direccion": sucursal.direccion,
                "sucursal_telefono": sucursal.telefono,
                "sucursal_latitud": sucursal.latitud,
                "sucursal_longitud": sucursal.longitud,
                "taller_id": sucursal.taller_id,
                "taller_nombre": taller_nombre,
                "distancia_km": distancia_km,
                "tiene_servicio": tiene_servicio,
                "rating": rating,
                "rating_count": rating_count,
                "tecnicos_disponibles": [],
                "score": 0.0,
            }

            candidatos.append(candidato)

        # ── Paso 5: Verificar técnicos disponibles ────────────
        for candidato in candidatos:
            tecnicos = await self.empleado_repo.get_disponibles(
                sucursal_id=candidato["sucursal_id"],
            )
            candidato["tecnicos_disponibles"] = [
                {"id": t.id, "especialidad": t.especialidad}
                for t in tecnicos
            ]

        # ── Paso 6: Calcular score y rankear ──────────────────
        for candidato in candidatos:
            candidato["score"] = self._calcular_score(candidato)

        candidatos.sort(key=lambda c: c["score"], reverse=True)
        logger.info(
            f"[Recomendación] {len(candidatos)} candidatos rankeados. "
            f"Mejor: {candidatos[0]['sucursal_nombre']} "
            f"(score={candidatos[0]['score']}, rating={candidatos[0]['rating']})"
            if candidatos else ""
        )
        return candidatos

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

    async def obtener_asignaciones_solicitud(self, solicitud_id: int) -> list[Asignacion]:
        return list(await self.asignacion_repo.get_by_solicitud(solicitud_id))

    async def obtener_asignacion_activa(self, solicitud_id: int) -> Asignacion | None:
        return await self.asignacion_repo.get_activa_de_solicitud(solicitud_id)

    # ══════════════════════════════════════════════════════════
    #  Métodos internos del algoritmo
    # ══════════════════════════════════════════════════════════

    async def _obtener_servicios_compatibles_batch(
        self,
        sucursal_ids: list[int],
        servicios_requeridos: list[str],
    ) -> set[int]:
        """
        Consulta batch: devuelve el SET de sucursal_ids que ofrecen
        al menos uno de los servicios requeridos.
        Una sola query en vez de N consultas individuales.
        """
        if not servicios_requeridos or not sucursal_ids:
            return set()

        stmt = (
            select(SucursalServicio.sucursal_id)
            .join(Servicio, SucursalServicio.servicio_id == Servicio.id)
            .where(
                SucursalServicio.sucursal_id.in_(sucursal_ids),
                Servicio.nombre.in_(servicios_requeridos),
            )
            .distinct()
        )
        result = await self.session.execute(stmt)
        return set(result.scalars().all())

    async def _obtener_ratings_batch(
        self,
        sucursal_ids: list[int],
    ) -> dict[int, float]:
        """
        Consulta agregada batch: devuelve {sucursal_id: avg_rating}
        en una sola query. Evita el problema N+1.
        Las sucursales sin reseñas no aparecerán (se asume 0.0).
        """
        if not sucursal_ids:
            return {}

        stmt = (
            select(
                ResenaForo.sucursal_id,
                func.avg(ResenaForo.puntuacion).label("rating_promedio"),
                func.count(ResenaForo.id).label("rating_count"),
            )
            .where(ResenaForo.sucursal_id.in_(sucursal_ids))
            .group_by(ResenaForo.sucursal_id)
        )
        result = await self.session.execute(stmt)
        rows = result.all()

        return {
            row.sucursal_id: {
                "rating": round(float(row.rating_promedio), 2),
                "rating_count": int(row.rating_count)
            }
            for row in rows
        }

    def _calcular_score(self, candidato: dict) -> float:
        """
        Calcula un puntaje para cada sucursal candidata.
        Factores (mayor = mejor):
          - Servicio compatible: +25 si tiene al menos uno de los servicios requeridos
          - Reputación (rating): +rating * 8 (máx +40 para 5 estrellas)
          - Distancia: -2 puntos por km (más cerca = mejor)
          - Técnicos: +5 por cada técnico disponible (máx +15)

        Pesos equilibrados:
          - Un taller con 5★ y servicio compatible a 5km:
            25 + 40 - 10 + 5 = 60
          - Un taller con 3★ y servicio compatible a 2km:
            25 + 24 - 4 + 5  = 50
          - Un taller SIN servicio compatible con 5★ a 1km:
            0 + 40 - 2 + 5   = 43  (penalizado, queda abajo)
        """
        score = 0.0

        # Bonificar por tener el servicio requerido
        if candidato["tiene_servicio"]:
            score += 25.0

        # Bonificar por reputación (rating 0-5 → 0-40 puntos)
        rating = candidato.get("rating", 0.0)
        score += rating * 8.0

        # Penalizar distancia: -2pts por km
        score -= candidato["distancia_km"] * 2.0

        # Bonificar por técnicos disponibles (máx 3 cuentan)
        num_tecnicos = min(len(candidato["tecnicos_disponibles"]), 3)
        score += num_tecnicos * 5.0

        return round(score, 2)

    def _seleccionar_mejor(self, candidatos: list[dict]) -> dict | None:
        """
        Selecciona el mejor candidato:
        Debe tener al menos un técnico disponible.
        """
        for candidato in candidatos:
            if candidato["tecnicos_disponibles"]:
                return candidato
        return None
