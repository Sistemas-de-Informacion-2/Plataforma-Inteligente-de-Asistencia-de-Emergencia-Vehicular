# backend/app/services/puja_service.py
"""
Servicio: Puja — Motor del Marketplace en Tiempo Real (inDrive).
Recepción de pujas y envío en vivo al cliente.
  1. Valida que la solicitud exista y esté en ESPERANDO_PUJAS.
  2. Valida que la sucursal no haya pujado ya.
  3. Calcula ETA con PostGIS (distancia / 30 km/h * 60 min).
  4. Obtiene rating histórico de la sucursal.
  5. Guarda la puja en BD.
  6. Emite NUEVA_PUJA_RECIBIDA vía WebSocket al cliente.
Selección de puja ganadora (Match Final).
  1. Marca puja ganadora como ACEPTADA.
  2. Rechaza las demás pujas.
  3. Cambia estado de solicitud a EN_PROCESO.
  4. Crea Asignación.
  5. Notifica a ganador, perdedores y cliente vía WebSocket.
"""
import logging
import math
from typing import Any

from sqlalchemy import select, func, cast
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2 import Geography
from geoalchemy2.elements import WKTElement

from app.models.puja import Puja, EstadoPuja
from app.models.taller import Sucursal, Taller
from app.models.admin import Admin
from app.models.asignacion import EstadoAsignacion
from app.models.resena import ResenaForo
from app.models.solicitud_emergencia import SolicitudEmergencia, EstadoSolicitud
from app.repositories.puja_repository import PujaRepository
from app.repositories.asignacion_repository import AsignacionRepository
from app.services.notificacion_service import NotificacionService

logger = logging.getLogger(__name__)

# Velocidad promedio urbana para cálculo de ETA (km/h)
VELOCIDAD_URBANA_KMH = 30.0
# ETA mínimo en minutos (para distancias muy cortas)
ETA_MINIMO_MINUTOS = 5


class PujaService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.puja_repo = PujaRepository(session)
        self.asignacion_repo = AsignacionRepository(session)
        self.notificacion_service = NotificacionService(session)

    # Crear puja + enviar en vivo al cliente
    async def crear_puja(
        self,
        solicitud_id: int,
        sucursal_id: int,
        precio_estimado: float,
    ) -> dict[str, Any]:
        """
        Flujo completo de recepción de puja (inDrive real-time):
        1. Validar solicitud (existe, estado ESPERANDO_PUJAS).
        2. Validar que la sucursal no haya pujado ya.
        3. Calcular ETA con PostGIS.
        4. Obtener rating histórico.
        5. Guardar puja en BD.
        6. Emitir WebSocket NUEVA_PUJA_RECIBIDA al cliente.
        Returns:
            Dict con la puja creada y los datos enriquecidos.
        Raises:
            ValueError: Si la validación falla.
        """
        # 1. Validar solicitud
        solicitud = await self.session.get(SolicitudEmergencia, solicitud_id)
        if not solicitud:
            raise ValueError(f"Solicitud #{solicitud_id} no encontrada.")

        if solicitud.estado != EstadoSolicitud.ESPERANDO_PUJAS:
            raise ValueError(
                f"La solicitud #{solicitud_id} no está aceptando pujas "
                f"(estado actual: {solicitud.estado.value})."
            )

        # 2. Validar que no haya pujado ya
        ya_pujo = await self.puja_repo.ya_pujo_sucursal(solicitud_id, sucursal_id)
        if ya_pujo:
            raise ValueError(
                f"La sucursal #{sucursal_id} ya envió una puja para la solicitud #{solicitud_id}."
            )

        # 3. Calcular ETA con PostGIS
        sucursal = await self.session.get(Sucursal, sucursal_id)
        if not sucursal:
            raise ValueError(f"Sucursal #{sucursal_id} no encontrada.")

        distancia_km = await self._calcular_distancia_km(
            sucursal, solicitud.latitud, solicitud.longitud
        )

        # ETA = distancia / velocidad * 60 min
        eta_minutos = max(
            ETA_MINIMO_MINUTOS,
            math.ceil((distancia_km / VELOCIDAD_URBANA_KMH) * 60)
        )

        # 4. Obtener rating histórico
        rating_data = await self._obtener_rating_sucursal(sucursal_id)

        # 5. Obtener nombre del taller padre
        taller = await self.session.get(Taller, sucursal.taller_id)
        taller_nombre = taller.nombre if taller else ""

        # 6. Guardar puja en BD
        puja_data = {
            "solicitud_id": solicitud_id,
            "sucursal_id": sucursal_id,
            "precio_estimado": precio_estimado,
            "tiempo_llegada_minutos": eta_minutos,
            "estado": EstadoPuja.PENDIENTE,
        }
        puja = await self.puja_repo.create(puja_data)

        logger.info(
            f"[Puja] Puja #{puja.id} creada: Sucursal #{sucursal_id} → "
            f"Solicitud #{solicitud_id} (${precio_estimado}, ETA={eta_minutos}min)"
        )

        # 7. Emisión del WebSocket al cliente
        ws_payload = {
            "type": "NUEVA_PUJA_RECIBIDA",
            "puja_id": puja.id,
            "solicitud_id": solicitud_id,
            "sucursal_id": sucursal_id,
            "sucursal_nombre": sucursal.nombre,
            "taller_nombre": taller_nombre,
            "precio_estimado": precio_estimado,
            "tiempo_llegada_minutos": eta_minutos,
            "rating": rating_data["rating"],
            "rating_count": rating_data["rating_count"],
            "distancia_km": distancia_km,
            "fecha": puja.fecha.isoformat(),
        }

        try:
            from app.api.v1.endpoints.notificaciones_ws import manager
            await manager.send_personal_message(
                ws_payload,
                str(solicitud.cliente_id)
            )
            logger.info(f"[Puja] WS NUEVA_PUJA_RECIBIDA enviado al cliente {solicitud.cliente_id}")
        except Exception as e:
            logger.error(f"[Puja] Error enviando WebSocket al cliente: {e}")

        return {
            "puja": puja,
            "sucursal_nombre": sucursal.nombre,
            "taller_nombre": taller_nombre,
            "rating": rating_data["rating"],
            "rating_count": rating_data["rating_count"],
            "distancia_km": distancia_km,
        }

    #  Fase 5: Seleccionar puja ganadora (Match Final)
    async def seleccionar_puja(
        self,
        solicitud_id: int,
        puja_id: int,
        current_user_id: int,
    ) -> dict[str, Any]:
        """
        Match Final: el cliente elige su puja favorita.
        1. Validar pertenencia y estado.
        2. Marcar puja ganadora como ACEPTADA.
        3. Rechazar las demás pujas.
        4. Cambiar solicitud a OFERTA_ACEPTADA.
        5. Crear Asignación (sin mecánico — el admin lo asignará).
        6. Notificar a todos vía WebSocket.
        Returns:
            Dict con la asignación creada y los datos del taller ganador.
        Raises:
            ValueError: Si la validación falla.
        """
        # 1. Validar solicitud
        solicitud = await self.session.get(SolicitudEmergencia, solicitud_id)
        if not solicitud:
            raise ValueError(f"Solicitud #{solicitud_id} no encontrada.")

        if solicitud.cliente_id != current_user_id:
            raise ValueError("No puedes seleccionar una puja de una solicitud que no te pertenece.")

        if solicitud.estado != EstadoSolicitud.ESPERANDO_PUJAS:
            raise ValueError(
                f"La solicitud #{solicitud_id} no está en estado ESPERANDO_PUJAS "
                f"(estado actual: {solicitud.estado.value})."
            )

        # 2. Validar puja
        puja = await self.puja_repo.get_by_id(puja_id)
        if not puja:
            raise ValueError(f"Puja #{puja_id} no encontrada.")

        if puja.solicitud_id != solicitud_id:
            raise ValueError(f"La puja #{puja_id} no pertenece a la solicitud #{solicitud_id}.")

        if puja.estado != EstadoPuja.PENDIENTE:
            raise ValueError(f"La puja #{puja_id} ya no está pendiente (estado: {puja.estado.value}).")

        # 3. Aceptar puja ganadora
        await self.puja_repo.aceptar_puja(puja_id)
        logger.info(f"[Match] Puja #{puja_id} → ACEPTADA")

        # 4. Rechazar las demás pujas
        rechazadas = await self.puja_repo.rechazar_pujas_restantes(solicitud_id, puja_id)
        logger.info(f"[Match] {rechazadas} pujas restantes → RECHAZADA")

        # 5. Cambiar estado de solicitud a OFERTA_ACEPTADA (el admin asignará mecánico)
        solicitud.estado = EstadoSolicitud.OFERTA_ACEPTADA
        await self.session.flush()
        logger.info(f"[Match] Solicitud #{solicitud_id} → OFERTA_ACEPTADA")

        # 6. Crear Asignación (sin mecánico todavía)
        asignacion_data = {
            "solicitud_id": solicitud_id,
            "sucursal_id": puja.sucursal_id,
            "empleado_id": None,  # El admin del taller asignará luego al mecánico
            "estado": EstadoAsignacion.PENDIENTE,
            "tiempo_estimado_llegada": puja.tiempo_llegada_minutos,
        }
        asignacion = await self.asignacion_repo.create(asignacion_data)
        logger.info(f"[Match] Asignación #{asignacion.id} creada para sucursal #{puja.sucursal_id}")

        # 7. Obtener datos del taller ganador
        sucursal = await self.session.get(Sucursal, puja.sucursal_id)
        taller = await self.session.get(Taller, sucursal.taller_id) if sucursal else None

        # 8. Notificaciones WebSocket
        try:
            from app.api.v1.endpoints.notificaciones_ws import manager

            # Al cliente: confirmación
            await manager.send_personal_message(
                {
                    "type": "PUJA_ACEPTADA",
                    "solicitud_id": solicitud_id,
                    "puja_id": puja_id,
                    "mensaje": "¡Oferta seleccionada! El taller ha sido notificado.",
                    "sucursal": {
                        "id": sucursal.id,
                        "nombre": sucursal.nombre,
                        "taller_nombre": taller.nombre if taller else "",
                        "telefono": sucursal.telefono,
                        "latitud": sucursal.latitud,
                        "longitud": sucursal.longitud,
                    },
                    "precio_estimado": puja.precio_estimado,
                    "tiempo_estimado": puja.tiempo_llegada_minutos,
                },
                str(solicitud.cliente_id)
            )

            # Al admin del taller ganador: tu puja fue elegida, asigna un mecánico
            admin_ganador_id = await self._obtener_admin_usuario_id(puja.sucursal_id)
            if admin_ganador_id:
                await manager.send_personal_message(
                    {
                        "type": "PUJA_GANADORA",
                        "solicitud_id": solicitud_id,
                        "puja_id": puja_id,
                        "asignacion_id": asignacion.id,
                        "mensaje": (
                            f"¡Tu oferta de Bs. {puja.precio_estimado} fue aceptada "
                            f"por el cliente! Asigna un mecánico para atender la emergencia."
                        ),
                    },
                    str(admin_ganador_id)
                )

                # Notificación persistente al ganador
                await self.notificacion_service.enviar_a_usuario(
                    usuario_id=admin_ganador_id,
                    mensaje=(
                        f"Tu oferta de Bs. {puja.precio_estimado} para la emergencia "
                        f"#{solicitud_id} fue aceptada. Asigna un mecánico desde tu panel."
                    )
                )

            # A los talleres perdedores: tu puja fue rechazada
            import asyncio
            pujas_perdedoras = await self.puja_repo.get_by_solicitud(solicitud_id)
            tareas_notificacion = []
            
            for puja_perdedora in pujas_perdedoras:
                if puja_perdedora.id == puja_id:
                    continue  # Saltar al ganador
                if puja_perdedora.estado != EstadoPuja.RECHAZADA:
                    continue

                admin_perdedor_id = await self._obtener_admin_usuario_id(puja_perdedora.sucursal_id)
                if admin_perdedor_id:
                    mensaje_ws = {
                        "type": "PUJA_RECHAZADA",
                        "solicitud_id": solicitud_id,
                        "puja_id": puja_perdedora.id,
                        "mensaje": "El cliente eligió otra oferta para esta emergencia.",
                    }
                    tareas_notificacion.append(manager.send_personal_message(mensaje_ws, str(admin_perdedor_id)))

            if tareas_notificacion:
                await asyncio.gather(*tareas_notificacion)

        except Exception as e:
            logger.error(f"[Match] Error en notificaciones WebSocket: {e}")

        return {
            "asignacion_id": asignacion.id,
            "puja_ganadora": {
                "id": puja.id,
                "precio_estimado": puja.precio_estimado,
                "tiempo_llegada_minutos": puja.tiempo_llegada_minutos,
            },
            "sucursal": {
                "id": sucursal.id if sucursal else None,
                "nombre": sucursal.nombre if sucursal else "",
                "taller_nombre": taller.nombre if taller else "",
            },
        }

    async def rechazar_puja_cliente(self, puja_id: int, current_user_id: int) -> None:
        """
        El cliente rechaza una puja individual explícitamente o por expiración.
        """
        puja = await self.puja_repo.get_by_id(puja_id)
        if not puja:
            raise ValueError(f"Puja #{puja_id} no encontrada.")

        solicitud = await self.session.get(SolicitudEmergencia, puja.solicitud_id)
        if not solicitud:
            raise ValueError(f"Solicitud no encontrada.")

        if solicitud.cliente_id != current_user_id:
            raise ValueError("No puedes rechazar una puja de una solicitud que no te pertenece.")

        if puja.estado != EstadoPuja.PENDIENTE:
            raise ValueError(f"La puja #{puja_id} no está pendiente.")

        # Actualizar estado a RECHAZADA
        await self.puja_repo.update(puja_id, {"estado": EstadoPuja.RECHAZADA})
        logger.info(f"[Puja] Puja #{puja_id} RECHAZADA por el cliente.")

        # Notificar al taller para que vuelva a pujar
        admin_id = await self._obtener_admin_usuario_id(puja.sucursal_id)
        if admin_id:
            try:
                from app.api.v1.endpoints.notificaciones_ws import manager
                await manager.send_personal_message(
                    {
                        "type": "PUJA_RECHAZADA_CLIENTE",
                        "solicitud_id": solicitud.id,
                        "puja_id": puja_id,
                    },
                    str(admin_id)
                )
            except Exception as e:
                logger.error(f"[Puja] Error notificando PUJA_RECHAZADA_CLIENTE: {e}")

    #  Consultas
    async def listar_pujas_solicitud(self, solicitud_id: int) -> list[dict]:
        """
        Lista todas las pujas de una solicitud con datos enriquecidos.
        Usado para reconexión del cliente (carga inicial de pujas existentes).
        """
        pujas = await self.puja_repo.get_by_solicitud(solicitud_id)
        resultado = []

        for puja in pujas:
            sucursal = await self.session.get(Sucursal, puja.sucursal_id)
            taller = await self.session.get(Taller, sucursal.taller_id) if sucursal else None
            rating_data = await self._obtener_rating_sucursal(puja.sucursal_id)

            distancia_km = 0.0
            solicitud = await self.session.get(SolicitudEmergencia, puja.solicitud_id)
            if sucursal and solicitud:
                distancia_km = await self._calcular_distancia_km(
                    sucursal, solicitud.latitud, solicitud.longitud
                )

            resultado.append({
                "id": puja.id,
                "solicitud_id": puja.solicitud_id,
                "sucursal_id": puja.sucursal_id,
                "sucursal_nombre": sucursal.nombre if sucursal else "",
                "taller_nombre": taller.nombre if taller else "",
                "precio_estimado": puja.precio_estimado,
                "tiempo_llegada_minutos": puja.tiempo_llegada_minutos,
                "estado": puja.estado.value,
                "rating": rating_data["rating"],
                "rating_count": rating_data["rating_count"],
                "distancia_km": distancia_km,
                "fecha": puja.fecha.isoformat(),
            })

        return resultado

    #  Métodos internos
    async def _calcular_distancia_km(
        self,
        sucursal: Sucursal,
        lat_destino: float,
        lng_destino: float,
    ) -> float:
        """
        Calcula la distancia en km entre una sucursal y un punto
        usando PostGIS ST_Distance con Geography cast.
        """
        if not sucursal.ubicacion:
            # Fallback: cálculo Haversine simple si no hay geometría PostGIS
            return self._haversine(
                sucursal.latitud, sucursal.longitud,
                lat_destino, lng_destino
            )

        punto_destino = WKTElement(
            f"POINT({lng_destino} {lat_destino})", srid=4326
        )

        stmt = select(
            func.ST_Distance(
                cast(Sucursal.ubicacion, Geography),
                cast(punto_destino, Geography),
            ).label("distancia_m")
        ).where(Sucursal.id == sucursal.id)

        result = await self.session.execute(stmt)
        distancia_m = result.scalar_one_or_none()

        if distancia_m is not None:
            return round(distancia_m / 1000, 2)

        return self._haversine(
            sucursal.latitud, sucursal.longitud,
            lat_destino, lng_destino
        )

    @staticmethod
    def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Cálculo Haversine como fallback si no hay geometría PostGIS."""
        R = 6371  # Radio de la Tierra en km
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = (
            math.sin(dlat / 2) ** 2
            + math.cos(math.radians(lat1))
            * math.cos(math.radians(lat2))
            * math.sin(dlon / 2) ** 2
        )
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return round(R * c, 2)

    async def _obtener_rating_sucursal(self, sucursal_id: int) -> dict:
        """Obtiene el rating promedio y cantidad de reseñas de una sucursal."""
        stmt = (
            select(
                func.avg(ResenaForo.puntuacion).label("rating"),
                func.count(ResenaForo.id).label("count"),
            )
            .where(ResenaForo.sucursal_id == sucursal_id)
        )
        result = await self.session.execute(stmt)
        row = result.one()
        return {
            "rating": round(float(row.rating), 2) if row.rating else 0.0,
            "rating_count": int(row.count) if row.count else 0,
        }

    async def _obtener_admin_usuario_id(self, sucursal_id: int) -> int | None:
        """Obtiene el usuario_id del admin de la sucursal."""
        stmt = (
            select(Admin.usuario_id)
            .join(Taller, Admin.id == Taller.admin_id)
            .join(Sucursal, Taller.id == Sucursal.taller_id)
            .where(Sucursal.id == sucursal_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()
