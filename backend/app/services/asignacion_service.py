# backend/app/services/asignacion_service.py
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

from app.models.asignacion import Asignacion, EstadoAsignacion
from app.models.taller import Sucursal, Taller
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

    async def buscar_sucursales_aptas(
        self,
        latitud_incidente: float,
        longitud_incidente: float,
        tipo_problema: str,
        *,
        radio_km: float = 15.0,
        max_candidatos: int = 10,
    ) -> list[dict[str, Any]]:
        """
        Busca y rankea sucursales aptas SIN crear asignación.
        Usado en Fase 1 del flujo 'Uber para Mecánicos Inverso':
        el cliente recibe la lista y elige.

        Returns:
            Lista de candidatos ordenados por score descendente.
            Cada candidato contiene: sucursal_id, nombre, taller_nombre,
            distancia_km, tiene_servicio, tecnicos_disponibles, score, eta_minutos.
        """
        logger.info(
            f"[Recomendación] Buscando sucursales aptas en radio de {radio_km}km "
            f"desde ({latitud_incidente}, {longitud_incidente}) "
            f"para tipo: '{tipo_problema}'"
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

        # ── Paso 2: Filtrar por servicio compatible ───────────
        candidatos: list[dict[str, Any]] = []
        for item in sucursales_cercanas:
            sucursal: Sucursal = item["sucursal"]
            distancia_km: float = item["distancia_km"]

            tiene_servicio = await self._sucursal_ofrece_servicio(
                sucursal.id, tipo_problema
            )

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
                "tecnicos_disponibles": [],
                "score": -10.0 if not tiene_servicio else 0.0,
            }

            candidatos.append(candidato)

        # ── Paso 3: Verificar técnicos disponibles ────────────
        for candidato in candidatos:
            tecnicos = await self.empleado_repo.get_disponibles(
                sucursal_id=candidato["sucursal_id"],
            )
            candidato["tecnicos_disponibles"] = [
                {"id": t.id, "especialidad": t.especialidad}
                for t in tecnicos
            ]

        # ── Paso 4: Calcular score y rankear ──────────────────
        for candidato in candidatos:
            candidato["score"] = self._calcular_score(candidato)

        candidatos.sort(key=lambda c: c["score"], reverse=True)
        logger.info(
            f"[Recomendación] {len(candidatos)} candidatos rankeados. "
            f"Mejor: {candidatos[0]['sucursal_nombre']} "
            f"(score={candidatos[0]['score']})" if candidatos else ""
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

    #  Métodos internos del algoritmo
    async def _sucursal_ofrece_servicio(self, sucursal_id: int, tipo_problema: str) -> bool:
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

    def _seleccionar_mejor(self, candidatos: list[dict]) -> dict | None:
        """
        Selecciona el mejor candidato:
        Debe tener al menos un técnico disponible.
        """
        for candidato in candidatos:
            if candidato["tecnicos_disponibles"]:
                return candidato
        return None
