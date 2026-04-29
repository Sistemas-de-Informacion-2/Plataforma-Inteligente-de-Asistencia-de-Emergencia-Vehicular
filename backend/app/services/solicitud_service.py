# backend/app/services/solicitud_service.py
"""
Servicio: SolicitudEmergencia — EL ORQUESTADOR DE BASE DE DATOS.
Este servicio coordina la persistencia del flujo de emergencia:
  1. Guardar la solicitud en BD con el estado dictaminado por la IA.
  2. Asociar evidencias.
  3. Guardar el diagnóstico estructurado.
  4. Buscar sucursales recomendadas (PostGIS) sin auto-asignar.

Fase 1 — Modelo 'Uber para Mecánicos Inverso':
  El flujo se detiene en la recomendación. El cliente elige el taller.
  NO se crean Asignaciones ni Notificaciones en este paso.
"""
import logging
from typing import Any

from geoalchemy2.elements import WKTElement
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.diagnostico_ia import DiagnosticoIA
from app.models.evidencia import Evidencia
from app.models.solicitud_emergencia import SolicitudEmergencia, EstadoSolicitud
from app.models.taller import Sucursal, Taller
from app.models.admin import Admin
from app.models.empleado import Empleado
from app.models.asignacion import EstadoAsignacion
from app.repositories.solicitud_repository import SolicitudRepository
from app.repositories.evidencia_repository import EvidenciaRepository
from app.schemas.solicitud_emergencia import SolicitudCreate
from app.schemas.evidencia import EvidenciaCreate
from app.schemas.taller import RespuestaTaller
from app.services.asignacion_service import AsignacionService
from app.services.notificacion_service import NotificacionService

logger = logging.getLogger(__name__)

class SolicitudService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = SolicitudRepository(session)
        self.evidencia_repo = EvidenciaRepository(session)
        self.asignacion_service = AsignacionService(session)
        self.notificacion_service = NotificacionService(session)

    # ── Fase 1: Crear solicitud + diagnóstico + recomendaciones ──
    async def crear_solicitud_con_recomendaciones(
        self,
        solicitud_in: SolicitudCreate,
        evidencias_in: list[EvidenciaCreate],
        diagnostico: dict,
        estado_inicial: str
    ) -> dict[str, Any]:
        """
        Flujo principal de emergencia — Fase 1 (Recomendación).
        1. Guarda la Solicitud en BD.
        2. Asocia las Evidencias.
        3. Guarda el DiagnosticoIA.
        4. Busca sucursales aptas con PostGIS (sin crear Asignación).
        5. Retorna la solicitud, diagnóstico y lista de recomendaciones.

        El estado final de la solicitud será:
          - PENDIENTE_SELECCION_CLIENTE: si hay recomendaciones disponibles.
          - PENDIENTE: si no se encontraron talleres cercanos.
          - El estado_inicial tal cual si la IA rechazó (ej: RECHAZADO_POR_IA).
        """
        resultado = {
            "solicitud": None,
            "evidencias": [],
            "diagnostico": None,
            "sucursales_recomendadas": [],
        }

        # ── Paso 1: Crear la solicitud con estado PENDIENTE ──────
        logger.info(f"[Solicitud] Guardando emergencia para cliente {solicitud_in.cliente_id}")
        solicitud_data = solicitud_in.model_dump()

        # Iniciar con estado PENDIENTE; se actualizará después según las recomendaciones
        try:
            solicitud_data["estado"] = EstadoSolicitud(estado_inicial)
        except ValueError:
            solicitud_data["estado"] = EstadoSolicitud.PENDIENTE

        # Generar geometría PostGIS
        solicitud_data["ubicacion"] = WKTElement(f"POINT({solicitud_in.longitud} {solicitud_in.latitud})", srid=4326)

        solicitud = await self.repo.create(solicitud_data)
        resultado["solicitud"] = solicitud

        # ── Paso 2: Guardar evidencias ───────────────────────────
        if evidencias_in:
            for ev_data in evidencias_in:
                evidencia = Evidencia(
                    tipo=ev_data.tipo,
                    url=ev_data.url,
                    solicitud_id=solicitud.id,
                )
                self.session.add(evidencia)
                resultado["evidencias"].append(evidencia)
            await self.session.flush()

        # ── Paso 3: Guardar el Diagnóstico Estructurado ──────────
        nuevo_diagnostico = DiagnosticoIA(
            solicitud_id=solicitud.id,
            problema_detectado=diagnostico.get("resumen", "Problema desconocido"),
            nivel_gravedad=diagnostico.get("nivel_gravedad", "MEDIO"),
            prioridad=diagnostico.get("prioridad", "MEDIA"),
            costo_estimado_ia=0.0,
        )
        self.session.add(nuevo_diagnostico)
        await self.session.flush()
        await self.session.refresh(nuevo_diagnostico)
        resultado["diagnostico"] = nuevo_diagnostico

        # ── Paso 4: Buscar sucursales recomendadas (sin asignar) ─
        # Solo buscar si la IA no rechazó el incidente
        if estado_inicial not in ("RECHAZADO_POR_IA",):
            servicios_ia = diagnostico.get("servicios", [])

            logger.info(
                f"[Recomendación] Buscando talleres aptos para servicios: "
                f"{servicios_ia} (solicitud #{solicitud.id})"
            )

            candidatos = await self.asignacion_service.buscar_sucursales_aptas(
                latitud_incidente=solicitud.latitud,
                longitud_incidente=solicitud.longitud,
                servicios_requeridos=servicios_ia,
            )
            resultado["sucursales_recomendadas"] = candidatos

            # Actualizar estado según si encontramos recomendaciones
            if candidatos:
                await self.repo.actualizar_estado(solicitud.id, EstadoSolicitud.PENDIENTE_SELECCION_CLIENTE)
                logger.info(
                    f"[Solicitud] Estado → PENDIENTE_SELECCION_CLIENTE "
                    f"({len(candidatos)} opciones disponibles)"
                )
            else:
                logger.warning(
                    f"[Solicitud] No se encontraron talleres cercanos. "
                    f"Estado permanece: {solicitud.estado.value}"
                )
        return resultado

    # ── Fase 2: El cliente elige un taller ──
    async def seleccionar_taller(
        self,
        solicitud_id: int,
        sucursal_id: int,
        current_user_id: int
    ) -> bool:
        """
        El cliente selecciona un taller de las recomendaciones.
        1. Valida que la solicitud pertenezca al cliente y esté en estado correcto.
        2. Cambia el estado a ESPERANDO_ACEPTACION_TALLER.
        3. Notifica al admin de la sucursal (Persistente + WebSocket).
        """
        # 1. Obtener solicitud
        solicitud = await self.repo.get_by_id(solicitud_id)
        if not solicitud:
            return False

        # 2. Validar pertenencia y estado
        if solicitud.cliente_id != current_user_id:
            logger.warning(f"[Selección] Usuario {current_user_id} intentó seleccionar taller para solicitud {solicitud_id} que no le pertenece.")
            return False
        
        if solicitud.estado not in (EstadoSolicitud.PENDIENTE_SELECCION_CLIENTE, EstadoSolicitud.RECHAZADO_POR_TALLER):
            logger.warning(f"[Selección] La solicitud {solicitud_id} no está en estado válido para selección (Estado actual: {solicitud.estado.value}).")
            return False

        # 3. Cambiar estado
        await self.repo.actualizar_estado(solicitud_id, EstadoSolicitud.ESPERANDO_ACEPTACION_TALLER)
        logger.info(f"[Selección] Solicitud {solicitud_id} cambió a ESPERANDO_ACEPTACION_TALLER (Sucursal elegida: {sucursal_id}).")

        # 4. Encontrar admin de la sucursal
        stmt = (
            select(Admin.usuario_id)
            .join(Taller, Admin.id == Taller.admin_id)
            .join(Sucursal, Taller.id == Sucursal.taller_id)
            .where(Sucursal.id == sucursal_id)
        )
        result = await self.session.execute(stmt)
        admin_usuario_id = result.scalar_one_or_none()

        if admin_usuario_id:
            # 5. Notificación Persistente
            await self.notificacion_service.enviar_a_usuario(
                usuario_id=admin_usuario_id,
                mensaje=(
                    f"Nueva solicitud de emergencia #{solicitud_id} recibida. "
                    "Por favor, revisa y acepta para asignar a un técnico."
                )
            )

            # 6. WebSocket en tiempo real
            try:
                from app.api.v1.endpoints.notificaciones_ws import manager
                await manager.send_personal_message(
                    {
                        "type": "NUEVA_SOLICITUD_EMERGENCIA",
                        "solicitud_id": solicitud_id,
                        "mensaje": "Tienes una nueva solicitud de emergencia esperando tu aceptación."
                    },
                    str(admin_usuario_id)
                )
                logger.info(f"[Selección] WebSocket enviado al admin {admin_usuario_id}.")
            except Exception as e:
                logger.error(f"[Selección] Error enviando WebSocket: {e}")
        else:
            logger.warning(f"[Selección] No se encontró un administrador para la sucursal {sucursal_id}.")

        return True

    # ── Fase 3: El Taller responde ──
    async def responder_solicitud(
        self,
        solicitud_id: int,
        sucursal_id: int,
        admin_id: int,
        respuesta: RespuestaTaller
    ) -> bool:
        """
        El taller acepta o rechaza una solicitud.
        1. Valida propiedad de la sucursal por el admin.
        2. Valida estado de la solicitud.
        3. Si RECHAZA: Estado -> RECHAZADO_POR_TALLER + Notifica Cliente.
        4. Si ACEPTA: Estado -> EN_PROCESO + Crea Asignación + Notifica Cliente y Mecánico.
        """
        # 1. Validar que la sucursal pertenezca al admin (con eager load del taller y admin)
        from sqlalchemy.orm import selectinload
        stmt_propiedad = (
            select(Sucursal)
            .join(Taller, Sucursal.taller_id == Taller.id)
            .where(Sucursal.id == sucursal_id, Taller.admin_id == admin_id)
            .options(
                selectinload(Sucursal.taller).selectinload(Taller.admin).selectinload(Admin.usuario)
            )
        )
        res_propiedad = await self.session.execute(stmt_propiedad)
        sucursal = res_propiedad.scalar_one_or_none()
        if not sucursal:
            logger.warning(f"[Respuesta] Admin {admin_id} intentó responder para sucursal {sucursal_id} que no le pertenece.")
            return False

        # 2. Obtener y validar solicitud
        solicitud = await self.repo.get_by_id(solicitud_id)
        if not solicitud or solicitud.estado != EstadoSolicitud.ESPERANDO_ACEPTACION_TALLER:
            logger.warning(f"[Respuesta] Solicitud {solicitud_id} no encontrada o en estado incorrecto ({solicitud.estado.value if solicitud else 'N/A'}).")
            return False

        if not respuesta.aceptar:
            # ── CASO RECHAZO ──
            await self.repo.actualizar_estado(solicitud_id, EstadoSolicitud.RECHAZADO_POR_TALLER)
            
            # Notificar al cliente
            mensaje_cliente = f"El taller ha rechazado tu solicitud #{solicitud_id}. Por favor, elige otro taller de la lista de recomendaciones."
            await self.notificacion_service.enviar_a_usuario(solicitud.cliente_id, mensaje_cliente)
            
            try:
                from app.api.v1.endpoints.notificaciones_ws import manager
                await manager.send_personal_message(
                    {"type": "SOLICITUD_RECHAZADA_TALLER", "solicitud_id": solicitud_id, "mensaje": mensaje_cliente},
                    str(solicitud.cliente_id)
                )
            except Exception as e:
                logger.error(f"[Respuesta] Error WebSocket cliente (rechazo): {e}")
            
            logger.info(f"[Respuesta] Solicitud {solicitud_id} rechazada por taller {sucursal_id}.")
            return True

        # ── CASO ACEPTACIÓN ──
        # 1. Validar mecánico (si se proporcionó uno)
        tecnico = None
        if respuesta.empleado_id is not None:
            stmt_tecnico = (
                select(Empleado)
                .where(Empleado.id == respuesta.empleado_id)
                .options(selectinload(Empleado.usuario))
            )
            res_tecnico = await self.session.execute(stmt_tecnico)
            tecnico = res_tecnico.scalar_one_or_none()
            if not tecnico or tecnico.sucursal_id != sucursal_id or not tecnico.disponible:
                logger.warning(f"[Respuesta] Técnico {respuesta.empleado_id} no válido o no disponible para sucursal {sucursal_id}.")
                return False

        # 2. Cambiar estado solicitud
        await self.repo.actualizar_estado(solicitud_id, EstadoSolicitud.EN_PROCESO)

        # 3. Crear Asignación (con o sin empleado)
        from app.schemas.asignacion import AsignacionCreate
        asignacion_data = AsignacionCreate(
            solicitud_id=solicitud_id,
            empleado_id=tecnico.id if tecnico else None,
            sucursal_id=sucursal_id,
            estado=EstadoAsignacion.PENDIENTE,
            tiempo_estimado_llegada=15  # Default o calculado
        )
        await self.asignacion_service.asignacion_repo.create(asignacion_data.model_dump())

        # 4. Construir mensajes según si hay técnico o el admin va personalmente
        if tecnico:
            mensaje_cliente = f"¡Buenas noticias! El taller aceptó tu solicitud #{solicitud_id}. Un técnico va en camino."
            mensaje_mecanico = f"Tienes una nueva asignación de emergencia #{solicitud_id}. Revisa los detalles e inicia el viaje."
        else:
            mensaje_cliente = f"¡Buenas noticias! El taller aceptó tu solicitud #{solicitud_id}. El administrador del taller va en camino."

        # 5. Notificar al Cliente
        await self.notificacion_service.enviar_a_usuario(solicitud.cliente_id, mensaje_cliente)

        # 6. Notificar al Mecánico (solo si hay uno asignado)
        if tecnico:
            await self.notificacion_service.enviar_a_usuario(tecnico.usuario_id, mensaje_mecanico)

        # 7. Construir info de quien atiende (técnico o admin)
        if tecnico:
            persona_asignada = {
                "id": tecnico.id,
                "nombre": tecnico.usuario.nombre if tecnico.usuario else "Técnico",
                "apellidos": "",
                "es_admin": False
            }
        else:
            # Admin va personalmente — obtener sus datos del usuario
            admin_usuario = sucursal.taller.admin.usuario if sucursal.taller and sucursal.taller.admin else None
            persona_asignada = {
                "id": admin_id,
                "nombre": admin_usuario.nombre if admin_usuario else "Administrador",
                "apellidos": "",
                "es_admin": True
            }

        # 8. WebSockets
        try:
            from app.api.v1.endpoints.notificaciones_ws import manager
            # Al cliente
            await manager.send_personal_message(
                {
                    "type": "SOLICITUD_ACEPTADA_TALLER", 
                    "solicitud_id": solicitud_id, 
                    "mensaje": mensaje_cliente,
                    "asignacion_resultado": {
                        "sucursal": {
                            "id": sucursal.id,
                            "nombre": sucursal.nombre,
                            "taller_nombre": sucursal.taller.nombre if sucursal.taller else "Taller",
                            "telefono": sucursal.telefono,
                            "latitud": sucursal.latitud,
                            "longitud": sucursal.longitud
                        },
                        "tecnico_asignado": persona_asignada,
                        "tiempo_estimado": 15
                    }
                },
                str(solicitud.cliente_id)
            )
            # Al mecánico (si existe)
            if tecnico:
                await manager.send_personal_message(
                    {"type": "NUEVA_ASIGNACION_TECNICO", "solicitud_id": solicitud_id, "mensaje": mensaje_mecanico},
                    str(tecnico.usuario_id)
                )
        except Exception as e:
            logger.error(f"[Respuesta] Error WebSockets (aceptación): {e}")

        asignado_a = f"técnico {tecnico.id}" if tecnico else "admin (personalmente)"
        logger.info(f"[Respuesta] Solicitud {solicitud_id} aceptada y asignada a {asignado_a}.")
        return True

    #  Consultas
    async def obtener_por_id(self, solicitud_id: int) -> SolicitudEmergencia | None:
        return await self.repo.get_by_id(solicitud_id)

    async def obtener_detallada(self, solicitud_id: int) -> SolicitudEmergencia | None:
        """Solicitud con evidencias y diagnóstico precargados."""
        return await self.repo.get_detallada(solicitud_id)

    async def listar_por_cliente(
        self,
        cliente_id: int,
        skip: int = 0,
        limit: int = 100,
    ) -> list[SolicitudEmergencia]:
        return list(
            await self.repo.get_by_cliente(cliente_id, skip=skip, limit=limit)
        )

    async def listar_pendientes(self, skip: int = 0, limit: int = 100) -> list[SolicitudEmergencia]:
        return list(await self.repo.get_pendientes(skip=skip, limit=limit))

    async def listar_esperando_aceptacion(self, skip: int = 0, limit: int = 100) -> list[SolicitudEmergencia]:
        """Solicitudes en estado ESPERANDO_ACEPTACION_TALLER con evidencias y diagnóstico precargados."""
        return list(
            await self.repo.get_detalladas_por_estado(
                EstadoSolicitud.ESPERANDO_ACEPTACION_TALLER, skip=skip, limit=limit
            )
        )

    async def listar_por_estado(self, estado: EstadoSolicitud, skip: int = 0, limit: int = 100) -> list[SolicitudEmergencia]:
        """Solicitudes filtradas por cualquier estado, con evidencias y diagnóstico precargados."""
        return list(
            await self.repo.get_detalladas_por_estado(estado, skip=skip, limit=limit)
        )

    async def listar_todas(self, skip: int = 0, limit: int = 100) -> list[SolicitudEmergencia]:
        return list(await self.repo.get_all(skip=skip, limit=limit))

    #  Actualización de estado
    async def actualizar_estado(
        self,
        solicitud_id: int,
        nuevo_estado: EstadoSolicitud,
    ) -> SolicitudEmergencia | None:
        """Actualiza el estado en BD."""
        return await self.repo.actualizar_estado(solicitud_id, nuevo_estado)

    #  Agregar evidencia a solicitud existente
    async def agregar_evidencia(self, data: EvidenciaCreate) -> Evidencia:
        """Agrega una evidencia a una solicitud existente."""
        return await self.evidencia_repo.create(data.model_dump())

    async def obtener_evidencias(self, solicitud_id: int) -> list[Evidencia]:
        return list(await self.evidencia_repo.get_by_solicitud(solicitud_id))
