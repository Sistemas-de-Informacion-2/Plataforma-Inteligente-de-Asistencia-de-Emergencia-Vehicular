# backend/app/services/solicitud_service.py
"""
Servicio: SolicitudEmergencia — EL ORQUESTADOR DE BASE DE DATOS.
Este servicio coordina la persistencia del flujo de emergencia:
  1. Guardar la solicitud en BD con el estado dictaminado por la IA.
  2. Asociar evidencias.
  3. Guardar el diagnóstico estructurado.
  4. Buscar sucursales recomendadas (PostGIS) sin auto-asignar.

Modelo 'Uber para Mecánicos Inverso':
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
from app.models.asignacion import Asignacion, EstadoAsignacion
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

    # ── Fase 1+2: Crear solicitud + diagnóstico + SOS Broadcast ──
    async def crear_solicitud_y_emitir_sos(
        self, solicitud_in: SolicitudCreate, evidencias_in: list[EvidenciaCreate],
        diagnostico: dict, estado_inicial: str) -> dict[str, Any]:
        """
        Flujo principal de emergencia — Marketplace de Pujas (inDrive).
        1. Guarda la Solicitud en BD.
        2. Asocia las Evidencias.
        3. Guarda el DiagnosticoIA.
        4. Busca sucursales cercanas y compatibles con PostGIS.
        5. Emite NUEVO_SOS_ZONA vía WebSocket a los admins de talleres cercanos.
        6. Cambia estado a ESPERANDO_PUJAS.

        NO retorna lista de recomendaciones.
        Las pujas llegarán al cliente en tiempo real vía WS (Fase 3).
        """
        resultado = {
            "solicitud": None,
            "evidencias": [],
            "diagnostico": None,
            "talleres_notificados": 0,
        }

        # Paso 1: Crear la solicitud con estado PENDIENTE
        logger.info(f"[SOS] Guardando emergencia para cliente {solicitud_in.cliente_id}")
        solicitud_data = solicitud_in.model_dump()

        try:
            solicitud_data["estado"] = EstadoSolicitud(estado_inicial)
        except ValueError:
            solicitud_data["estado"] = EstadoSolicitud.PENDIENTE

        # Generar geometría PostGIS
        solicitud_data["ubicacion"] = WKTElement(f"POINT({solicitud_in.longitud} {solicitud_in.latitud})", srid=4326)

        solicitud = await self.repo.create(solicitud_data)
        resultado["solicitud"] = solicitud

        # Paso 2: Guardar evidencias
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

        # Paso 3: Guardar el Diagnóstico Estructurado
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

        # Paso 4: Broadcast SOS a talleres cercanos, solo emitir si la IA no rechazó el incidente
        if estado_inicial not in ("RECHAZADO_POR_IA",):
            servicios_ia = diagnostico.get("servicios", [])
            logger.info(
                f"[SOS] Buscando talleres cercanos para broadcast "
                f"(servicios: {servicios_ia}, solicitud #{solicitud.id})"
            )

            # Reutilizar la búsqueda de sucursales cercanas para encontrar
            # a quién notificar (admins de talleres cercanos y compatibles)
            candidatos = await self.asignacion_service.buscar_sucursales_aptas(
                latitud_incidente=solicitud.latitud,
                longitud_incidente=solicitud.longitud,
                servicios_requeridos=servicios_ia,
                radio_km=15.0,
                max_candidatos=20,
            )

            if candidatos:
                # Cambiar estado a ESPERANDO_PUJAS
                await self.repo.actualizar_estado(solicitud.id, EstadoSolicitud.ESPERANDO_PUJAS)
                logger.info(
                    f"[SOS] Estado → ESPERANDO_PUJAS "
                    f"({len(candidatos)} sucursales encontradas)"
                )

                # Obtener usuario_ids de los admins de cada taller
                admin_usuario_ids = await self._obtener_admin_ids_de_sucursales(
                    [c["sucursal_id"] for c in candidatos]
                )

                if admin_usuario_ids:
                    # Construir payload del SOS
                    sos_payload = {
                        "type": "NUEVO_SOS_ZONA",
                        "solicitud_id": solicitud.id,
                        "cliente_ubicacion": {
                            "latitud": solicitud.latitud,
                            "longitud": solicitud.longitud,
                        },
                        "diagnostico": {
                            "problema": diagnostico.get("resumen", ""),
                            "servicios_requeridos": servicios_ia,
                            "nivel_gravedad": diagnostico.get("nivel_gravedad", "MEDIO"),
                            "prioridad": diagnostico.get("prioridad", "MEDIA"),
                        },
                        "mensaje": "Nueva emergencia vehicular en tu zona. ¡Envía tu oferta!",
                    }

                    # Emitir broadcast vía WebSocket
                    try:
                        from app.api.v1.endpoints.notificaciones_ws import manager
                        enviados = await manager.broadcast_to_users(
                            sos_payload,
                            [str(uid) for uid in admin_usuario_ids]
                        )
                        resultado["talleres_notificados"] = enviados
                        logger.info(f"[SOS] Broadcast enviado a {enviados} admins de talleres.")
                    except Exception as e:
                        logger.error(f"[SOS] Error en broadcast WebSocket: {e}")

                    # También crear notificaciones persistentes para los admins
                    for admin_uid in admin_usuario_ids:
                        await self.notificacion_service.enviar_a_usuario(
                            usuario_id=admin_uid,
                            mensaje=(
                                f"Nueva emergencia #{solicitud.id} en tu zona. "
                                "Envía tu oferta de precio para atender al cliente."
                            )
                        )
            else:
                logger.warning(
                    f"[SOS] No se encontraron talleres cercanos. "
                    f"Estado permanece: {solicitud.estado.value}"
                )

        return resultado

    async def _obtener_admin_ids_de_sucursales(self, sucursal_ids: list[int],) -> list[int]:
        """
        Obtiene los usuario_id de los administradores de los talleres a los que pertenecen las sucursales dadas.
        Usado para el broadcast del SOS.
        """
        if not sucursal_ids:
            return []
        stmt = (
            select(Admin.usuario_id)
            .join(Taller, Admin.id == Taller.admin_id)
            .join(Sucursal, Taller.id == Sucursal.taller_id)
            .where(Sucursal.id.in_(sucursal_ids))
            .distinct()
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())


    #  FLUJO MARKETPLACE: Asignación y Ejecución de Trabajos
    async def asignar_mecanico(
        self,
        solicitud_id: int,
        sucursal_id: int,
        admin_id: int,
        empleado_id: int,
    ) -> Asignacion:
        """
        El Admin del taller (cuya puja fue aceptada) asigna un mecánico.

        Reglas de negocio:
          1. Solicitud debe estar en OFERTA_ACEPTADA.
          2. La sucursal debe pertenecer al admin.
          3. El mecánico NO debe tener otro trabajo activo.
          4. El mecánico debe pertenecer a esa sucursal.
          5. Actualiza la Asignación existente con el empleado_id.
          6. Cambia solicitud → ESPERANDO_CONFIRMACION_MECANICO.
          7. Notifica al mecánico por WS + persistente.

        Raises:
            ValueError: Si cualquier validación falla.
        """
        from sqlalchemy.orm import selectinload

        # 1. Obtener y validar solicitud
        solicitud = await self.repo.get_by_id(solicitud_id)
        if not solicitud:
            raise ValueError(f"Solicitud #{solicitud_id} no encontrada.")

        if solicitud.estado != EstadoSolicitud.OFERTA_ACEPTADA:
            raise ValueError(
                f"La solicitud #{solicitud_id} no está en estado OFERTA_ACEPTADA "
                f"(estado actual: {solicitud.estado.value}). "
                f"Solo puedes asignar mecánico después de que el cliente acepte una oferta."
            )

        # 2. Validar que la sucursal pertenezca al admin
        stmt_propiedad = (
            select(Sucursal)
            .join(Taller, Sucursal.taller_id == Taller.id)
            .where(Sucursal.id == sucursal_id, Taller.admin_id == admin_id)
        )
        res = await self.session.execute(stmt_propiedad)
        sucursal = res.scalar_one_or_none()
        if not sucursal:
            raise ValueError(
                f"La sucursal #{sucursal_id} no pertenece a tu taller."
            )

        # 3. Validar empleado si se proporciona
        empleado = None
        if empleado_id is not None:
            # REGLA CRÍTICA: Verificar que el mecánico NO tenga trabajo activo
            stmt_ocupado = (
                select(Asignacion)
                .where(
                    Asignacion.empleado_id == empleado_id,
                    Asignacion.solicitud_id != solicitud_id,
                    Asignacion.estado.in_([
                        EstadoAsignacion.PENDIENTE,
                        EstadoAsignacion.ACEPTADA,
                        EstadoAsignacion.EN_CAMINO,
                        EstadoAsignacion.EN_SITIO,
                    ]),
                )
                .limit(1)
            )
            res_ocupado = await self.session.execute(stmt_ocupado)
            trabajo_activo = res_ocupado.scalar_one_or_none()
            if trabajo_activo:
                raise ValueError(
                    f"El mecánico #{empleado_id} no está disponible. "
                    f"Tiene una asignación activa (#{trabajo_activo.id}, estado: {trabajo_activo.estado.value})."
                )

            # 4. Validar que el mecánico pertenezca a la sucursal
            stmt_empleado = (
                select(Empleado)
                .where(Empleado.id == empleado_id)
                .options(selectinload(Empleado.usuario))
            )
            res_empleado = await self.session.execute(stmt_empleado)
            empleado = res_empleado.scalar_one_or_none()
            if not empleado:
                raise ValueError(f"Empleado #{empleado_id} no encontrado.")
            if empleado.sucursal_id != sucursal_id:
                raise ValueError(
                    f"El mecánico #{empleado_id} no pertenece a la sucursal #{sucursal_id}."
                )
        else:
            # Es el Admin quien se autoasigna. Validar que el Admin no tenga trabajo activo.
            stmt_ocupado = (
                select(Asignacion)
                .where(
                    Asignacion.empleado_id.is_(None),
                    Asignacion.sucursal_id == sucursal_id,
                    Asignacion.solicitud_id != solicitud_id,
                    Asignacion.estado.in_([
                        EstadoAsignacion.PENDIENTE,
                        EstadoAsignacion.ACEPTADA,
                        EstadoAsignacion.EN_CAMINO,
                        EstadoAsignacion.EN_SITIO,
                    ]),
                )
                .limit(1)
            )
            res_ocupado = await self.session.execute(stmt_ocupado)
            trabajo_activo = res_ocupado.scalar_one_or_none()
            if trabajo_activo:
                raise ValueError(
                    f"Como administrador ya tienes una asignación activa "
                    f"(#{trabajo_activo.id}, estado: {trabajo_activo.estado.value})."
                )

        # 5. Obtener la Asignación existente (creada por seleccionar_puja)
        asignaciones = await self.asignacion_service.obtener_asignaciones_solicitud(solicitud_id)
        asignacion = asignaciones[0] if asignaciones else None
        if not asignacion:
            raise ValueError(
                f"No se encontró ninguna asignación para la solicitud #{solicitud_id}."
            )

        # Actualizar la asignación con el mecánico
        asignacion.empleado_id = empleado_id

        if empleado_id is not None:
            # Flujo normal con empleado: requiere confirmación
            asignacion.estado = EstadoAsignacion.PENDIENTE
            asignacion.motivo_rechazo = None

            await self.session.flush()
            await self.session.refresh(asignacion)

            # Cambiar estado de solicitud
            await self.repo.actualizar_estado(
                solicitud_id, EstadoSolicitud.ESPERANDO_CONFIRMACION_MECANICO
            )
            logger.info(
                f"[Asignación] Solicitud #{solicitud_id} → ESPERANDO_CONFIRMACION_MECANICO "
                f"(Mecánico #{empleado_id})"
            )

            # Notificar al mecánico
            mensaje = (
                f"Tienes una nueva asignación de emergencia #{solicitud_id}. "
                f"Revisa los detalles y acepta o rechaza."
            )
            await self.notificacion_service.enviar_a_usuario(empleado.usuario_id, mensaje)

            try:
                from app.api.v1.endpoints.notificaciones_ws import manager
                await manager.send_personal_message(
                    {
                        "type": "NUEVA_ASIGNACION_TECNICO",
                        "solicitud_id": solicitud_id,
                        "asignacion_id": asignacion.id,
                        "mensaje": mensaje,
                    },
                    str(empleado.usuario_id)
                )
                logger.info(f"[Asignación] WS enviado al mecánico {empleado.usuario_id}")
            except Exception as e:
                logger.error(f"[Asignación] Error WS mecánico: {e}")

            # Iniciar timeout de falta de respuesta del mecánico (1 minuto)
            import asyncio
            asyncio.create_task(
                verificar_respuesta_mecanico_timeout(
                    solicitud_id=solicitud_id,
                    asignacion_id=asignacion.id,
                    timeout_seconds=60
                )
            )
            logger.info(f"[Asignación] Tarea de timeout (60s) iniciada para asignación #{asignacion.id}")
        else:
            # Auto-asignación de Admin: Salta directamente a EN_CAMINO
            asignacion.estado = EstadoAsignacion.ACEPTADA
            await self.session.flush()
            await self.session.refresh(asignacion)

            await self.repo.actualizar_estado(
                solicitud_id, EstadoSolicitud.EN_CAMINO
            )
            logger.info(
                f"[Asignación] Solicitud #{solicitud_id} → EN_CAMINO "
                f"(Auto-asignación Admin)"
            )

            # Notificar al cliente que ya va en camino
            mensaje_cliente = "El taller aceptó la asignación y va en camino (Auto-asignación)."
            await self.notificacion_service.enviar_a_usuario(solicitud.cliente_id, mensaje_cliente)

            try:
                from app.api.v1.endpoints.notificaciones_ws import manager
                # El admin no tiene latitud/longitud en empleado, mandamos ubicación del taller
                lat = sucursal.latitud if sucursal else None
                lng = sucursal.longitud if sucursal else None
                
                await manager.send_personal_message(
                    {
                        "type": "MECANICO_EN_CAMINO",
                        "solicitud_id": solicitud.id,
                        "asignacion_id": asignacion.id,
                        "mecanico": {
                            "nombre": "Taller (Administrador)",
                            "latitud": lat,
                            "longitud": lng,
                        },
                        "mensaje": mensaje_cliente,
                    },
                    str(solicitud.cliente_id)
                )
            except Exception as e:
                logger.error(f"[Mecánico] Error WS cliente (auto-asignación): {e}")

        return asignacion

    # ── Respuesta del Mecánico ──────────────────────────────────
    async def responder_asignacion_mecanico(
        self,
        asignacion_id: int,
        usuario_id: int,
        aceptar: bool,
        motivo_rechazo: str | None = None,
    ) -> Asignacion:
        """
        El mecánico acepta o rechaza su asignación.

        Si acepta:
          - Asignación → ACEPTADA, Solicitud → EN_CAMINO.
          - WS al cliente: MECANICO_EN_CAMINO.

        Si rechaza:
          - Asignación → RECHAZADA + motivo, Solicitud → OFERTA_ACEPTADA.
          - WS al admin: MECANICO_RECHAZO (para que reasigne).

        Raises:
            ValueError: Si la asignación no existe, no pertenece al técnico, o no está PENDIENTE.
        """
        from sqlalchemy.orm import selectinload

        # 1. Obtener asignación con relaciones
        stmt = (
            select(Asignacion)
            .where(Asignacion.id == asignacion_id)
            .options(
                selectinload(Asignacion.empleado).selectinload(Empleado.usuario),
                selectinload(Asignacion.solicitud),
                selectinload(Asignacion.sucursal),
            )
        )
        res = await self.session.execute(stmt)
        asignacion = res.scalar_one_or_none()
        if not asignacion:
            raise ValueError(f"Asignación #{asignacion_id} no encontrada.")

        # 2. Validar que la asignación pertenezca a este técnico o al admin dueño
        if asignacion.empleado_id is not None:
            if not asignacion.empleado or asignacion.empleado.usuario_id != usuario_id:
                raise ValueError("Esta asignación no te pertenece.")
        else:
            admin_uid = await self._obtener_admin_de_sucursal(asignacion.sucursal_id)
            if admin_uid != usuario_id:
                raise ValueError("Esta asignación le pertenece a la sucursal y tú no eres el administrador.")

        # 3. Validar estado
        if asignacion.estado != EstadoAsignacion.PENDIENTE:
            raise ValueError(
                f"La asignación #{asignacion_id} no está pendiente "
                f"(estado actual: {asignacion.estado.value})."
            )

        solicitud = asignacion.solicitud

        if aceptar:
            # ── ACEPTAR ──
            asignacion.estado = EstadoAsignacion.ACEPTADA
            solicitud.estado = EstadoSolicitud.EN_CAMINO
            await self.session.flush()
            await self.session.refresh(asignacion)

            logger.info(
                f"[Mecánico] Asignación #{asignacion_id} ACEPTADA. "
                f"Solicitud #{solicitud.id} → EN_CAMINO"
            )

            # Notificar al cliente
            nombre_mecanico = asignacion.empleado.usuario.nombre if asignacion.empleado.usuario else "Tu mecánico"
            mensaje_cliente = f"{nombre_mecanico} aceptó la asignación y va en camino."
            await self.notificacion_service.enviar_a_usuario(solicitud.cliente_id, mensaje_cliente)

            # Notificar al admin
            admin_usuario_id = await self._obtener_admin_de_sucursal(asignacion.sucursal_id)
            if admin_usuario_id:
                mensaje_admin = f"El mecánico {nombre_mecanico} aceptó la asignación #{solicitud.id} y va en camino."
                await self.notificacion_service.enviar_a_usuario(admin_usuario_id, mensaje_admin)

            try:
                from app.api.v1.endpoints.notificaciones_ws import manager
                # WS Cliente
                await manager.send_personal_message(
                    {
                        "type": "MECANICO_EN_CAMINO",
                        "solicitud_id": solicitud.id,
                        "asignacion_id": asignacion_id,
                        "mecanico": {
                            "nombre": nombre_mecanico,
                            "latitud": asignacion.empleado.latitud,
                            "longitud": asignacion.empleado.longitud,
                        },
                        "mensaje": mensaje_cliente,
                    },
                    str(solicitud.cliente_id)
                )
                
                # WS Admin
                if admin_usuario_id:
                    await manager.send_personal_message(
                        {
                            "type": "MECANICO_EN_CAMINO",
                            "solicitud_id": solicitud.id,
                            "asignacion_id": asignacion_id,
                            "mensaje": mensaje_admin,
                        },
                        str(admin_usuario_id)
                    )
            except Exception as e:
                logger.error(f"[Mecánico] Error WS cliente/admin (aceptación): {e}")

        else:
            # ── RECHAZAR ──
            asignacion.estado = EstadoAsignacion.RECHAZADA
            asignacion.motivo_rechazo = motivo_rechazo
            asignacion.empleado_id = None  # Liberar mecánico de la asignación
            solicitud.estado = EstadoSolicitud.OFERTA_ACEPTADA  # Admin debe reasignar
            await self.session.flush()
            await self.session.refresh(asignacion)

            logger.info(
                f"[Mecánico] Asignación #{asignacion_id} RECHAZADA. "
                f"Motivo: {motivo_rechazo}. Solicitud #{solicitud.id} → OFERTA_ACEPTADA"
            )

            # Notificar al admin para que reasigne
            admin_usuario_id = await self._obtener_admin_de_sucursal(asignacion.sucursal_id)
            nombre_mecanico = asignacion.empleado.usuario.nombre if asignacion.empleado and asignacion.empleado.usuario else "El mecánico"
            mensaje_admin = (
                f"{nombre_mecanico} rechazó la asignación para la emergencia #{solicitud.id}. "
                f"Motivo: {motivo_rechazo or 'No especificado'}. Asigna otro mecánico."
            )

            if admin_usuario_id:
                await self.notificacion_service.enviar_a_usuario(admin_usuario_id, mensaje_admin)
                try:
                    from app.api.v1.endpoints.notificaciones_ws import manager
                    await manager.send_personal_message(
                        {
                            "type": "MECANICO_RECHAZO",
                            "solicitud_id": solicitud.id,
                            "asignacion_id": asignacion_id,
                            "motivo": motivo_rechazo,
                            "mensaje": mensaje_admin,
                        },
                        str(admin_usuario_id)
                    )
                except Exception as e:
                    logger.error(f"[Mecánico] Error WS admin (rechazo): {e}")

        return asignacion

    # ── Mecánico marca llegada ──────────────────────────────────
    async def marcar_llegada(
        self,
        asignacion_id: int,
        usuario_id: int,
    ) -> Asignacion:
        """
        El mecánico marca que llegó al sitio de la emergencia.
        Asignación → EN_SITIO, Solicitud → EN_SITIO.
        """
        from sqlalchemy.orm import selectinload

        stmt = (
            select(Asignacion)
            .where(Asignacion.id == asignacion_id)
            .options(
                selectinload(Asignacion.empleado).selectinload(Empleado.usuario),
                selectinload(Asignacion.solicitud),
            )
        )
        res = await self.session.execute(stmt)
        asignacion = res.scalar_one_or_none()
        if not asignacion:
            raise ValueError(f"Asignación #{asignacion_id} no encontrada.")

        if asignacion.empleado_id is not None:
            if not asignacion.empleado or asignacion.empleado.usuario_id != usuario_id:
                raise ValueError("Esta asignación no te pertenece.")
        else:
            admin_uid = await self._obtener_admin_de_sucursal(asignacion.sucursal_id)
            if admin_uid != usuario_id:
                raise ValueError("Esta asignación le pertenece a la sucursal y tú no eres el administrador.")

        if asignacion.estado != EstadoAsignacion.ACEPTADA:
            raise ValueError(
                f"No puedes marcar llegada en estado {asignacion.estado.value}. "
                f"Debe estar en ACEPTADA."
            )

        asignacion.estado = EstadoAsignacion.EN_SITIO
        asignacion.solicitud.estado = EstadoSolicitud.EN_SITIO
        await self.session.flush()
        await self.session.refresh(asignacion)

        logger.info(f"[Llegada] Asignación #{asignacion_id} → EN_SITIO")

        # Notificar al cliente
        if asignacion.empleado_id is not None and asignacion.empleado and asignacion.empleado.usuario:
            nombre = asignacion.empleado.usuario.nombre
        else:
            nombre = "El taller (Admin)"
            
        mensaje = f"{nombre} ha llegado al lugar de la emergencia."
        await self.notificacion_service.enviar_a_usuario(
            asignacion.solicitud.cliente_id, mensaje
        )

        # Notificar al admin
        admin_usuario_id = await self._obtener_admin_de_sucursal(asignacion.sucursal_id)
        if admin_usuario_id:
            mensaje_admin = f"{nombre} ha llegado al lugar de la emergencia #{asignacion.solicitud.id}."
            await self.notificacion_service.enviar_a_usuario(admin_usuario_id, mensaje_admin)

        try:
            from app.api.v1.endpoints.notificaciones_ws import manager
            # WS Cliente
            await manager.send_personal_message(
                {
                    "type": "MECANICO_EN_SITIO",
                    "solicitud_id": asignacion.solicitud.id,
                    "asignacion_id": asignacion_id,
                    "mensaje": mensaje,
                },
                str(asignacion.solicitud.cliente_id)
            )
            # WS Admin
            if admin_usuario_id:
                await manager.send_personal_message(
                    {
                        "type": "MECANICO_EN_SITIO",
                        "solicitud_id": asignacion.solicitud.id,
                        "asignacion_id": asignacion_id,
                        "mensaje": mensaje_admin,
                    },
                    str(admin_usuario_id)
                )
        except Exception as e:
            logger.error(f"[Llegada] Error WS cliente/admin: {e}")

        return asignacion

    # ── Finalizar trabajo ──────────────────────────────────────
    async def finalizar_trabajo(
        self,
        asignacion_id: int,
        usuario_id: int,
        monto_total: float | None = None,
    ) -> Asignacion:
        """
        El mecánico o admin finaliza el trabajo.
        Asignación → COMPLETADA, Solicitud → FINALIZADO.
        Si se provee monto_total, crea automáticamente el Pago.
        """
        from sqlalchemy import select
        from sqlalchemy.orm import selectinload
        from app.services.pago_service import PagoService

        stmt = (
            select(Asignacion)
            .where(Asignacion.id == asignacion_id)
            .options(
                selectinload(Asignacion.empleado).selectinload(Empleado.usuario),
                selectinload(Asignacion.solicitud),
            )
        )
        res = await self.session.execute(stmt)
        asignacion = res.scalar_one_or_none()
        if not asignacion:
            raise ValueError(f"Asignación #{asignacion_id} no encontrada.")

        if asignacion.empleado_id is not None:
            if not asignacion.empleado or asignacion.empleado.usuario_id != usuario_id:
                raise ValueError("Esta asignación no te pertenece.")
        else:
            admin_uid = await self._obtener_admin_de_sucursal(asignacion.sucursal_id)
            if admin_uid != usuario_id:
                raise ValueError("Esta asignación le pertenece a la sucursal y tú no eres el administrador.")

        if asignacion.estado != EstadoAsignacion.EN_SITIO:
            raise ValueError(
                f"No puedes finalizar en estado {asignacion.estado.value}. "
                f"Debe estar en EN_SITIO."
            )

        asignacion.estado = EstadoAsignacion.COMPLETADA
        asignacion.solicitud.estado = EstadoSolicitud.FINALIZADO
        await self.session.flush()
        await self.session.refresh(asignacion)

        logger.info(f"[Finalización] Asignación #{asignacion_id} → COMPLETADA, Solicitud → FINALIZADO")

        # Notificar al cliente
        mensaje = (
            f"El servicio para la emergencia #{asignacion.solicitud.id} ha sido finalizado. "
            f"Procede al pago y calificación."
        )
        await self.notificacion_service.enviar_a_usuario(
            asignacion.solicitud.cliente_id, mensaje
        )

        try:
            from app.api.v1.endpoints.notificaciones_ws import manager
            await manager.send_personal_message(
                {
                    "type": "SERVICIO_FINALIZADO",
                    "solicitud_id": asignacion.solicitud.id,
                    "asignacion_id": asignacion_id,
                    "mensaje": mensaje,
                },
                str(asignacion.solicitud.cliente_id)
            )
        except Exception as e:
            logger.error(f"[Finalización] Error WS cliente: {e}")

        # Si el técnico proporcionó el monto, creamos el pago automáticamente
        if monto_total is not None:
            try:
                pago_service = PagoService(self.session)
                admin_uid = await self._obtener_admin_de_sucursal(asignacion.sucursal_id)
                if admin_uid:
                    # El admin_uid es el usuario_id del admin, pero PagoService.crear_pago espera el admin_id (ID de la tabla Admin)
                    from app.models.admin import Admin
                    stmt_admin = select(Admin.id).where(Admin.usuario_id == admin_uid)
                    res_admin = await self.session.execute(stmt_admin)
                    admin_tabla_id = res_admin.scalar_one_or_none()

                    if admin_tabla_id:
                        await pago_service.crear_pago(
                            solicitud_id=asignacion.solicitud.id,
                            monto_total=monto_total,
                            admin_id=admin_tabla_id,
                            metodo_pago="APP"
                        )
            except Exception as e:
                logger.error(f"[Finalización] Error creando el pago automático: {e}")

        return asignacion

    # ── Helper: obtener admin de una sucursal ──────────────────
    async def _obtener_admin_de_sucursal(self, sucursal_id: int) -> int | None:
        """Obtiene el usuario_id del admin de la sucursal."""
        stmt = (
            select(Admin.usuario_id)
            .join(Taller, Admin.id == Taller.admin_id)
            .join(Sucursal, Taller.id == Sucursal.taller_id)
            .where(Sucursal.id == sucursal_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

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

    async def listar_por_sucursal_y_estado(
        self, sucursal_id: int, estado: EstadoSolicitud, skip: int = 0, limit: int = 100
    ) -> list[SolicitudEmergencia]:
        """Filtra por estado y por sucursal (para EN_PROCESO, ATENDIDO, etc)."""
        return list(
            await self.repo.get_detalladas_por_sucursal_y_estado(
                sucursal_id, estado, skip=skip, limit=limit
            )
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

    async def obtener_solicitud_activa_cliente(self, cliente_id: int) -> SolicitudEmergencia | None:
        """Devuelve la solicitud activa actual del cliente, si existe."""
        return await self.repo.get_activa_por_cliente(cliente_id)

    async def cancelar_solicitud_cliente(self, solicitud_id: int, cliente_id: int) -> None:
        """
        El cliente cancela su solicitud actual.
        Cambia estado a CANCELADO, rechaza pujas y notifica a talleres vía WS.
        """
        solicitud = await self.repo.get_by_id(solicitud_id)
        if not solicitud:
            raise ValueError(f"Solicitud #{solicitud_id} no encontrada.")

        if solicitud.cliente_id != cliente_id:
            raise ValueError("No tienes permiso para cancelar esta solicitud.")

        estados_cancelables = (
            EstadoSolicitud.PENDIENTE,
            EstadoSolicitud.ESPERANDO_PUJAS,
            EstadoSolicitud.OFERTA_ACEPTADA,
        )
        if solicitud.estado not in estados_cancelables:
            raise ValueError(f"No puedes cancelar una solicitud en estado {solicitud.estado.value}.")

        # 1. Cambiar estado a CANCELADO
        await self.repo.actualizar_estado(solicitud_id, EstadoSolicitud.CANCELADO)
        logger.info(f"[Cancelación] Solicitud #{solicitud_id} marcada como CANCELADA por el cliente.")

        # 2. Rechazar pujas pendientes si existen
        from app.repositories.puja_repository import PujaRepository
        puja_repo = PujaRepository(self.session)
        pujas_pendientes = await puja_repo.get_by_solicitud(solicitud_id)
        
        from app.models.puja import EstadoPuja
        for puja in pujas_pendientes:
            if puja.estado == EstadoPuja.PENDIENTE:
                await puja_repo.update(puja.id, {"estado": EstadoPuja.RECHAZADA})

        # 3. Notificar a talleres para limpiar radar
        try:
            from app.api.v1.endpoints.notificaciones_ws import manager
            # Broadcast a los talleres para que retiren la tarjeta del radar
            await manager.broadcast({
                "type": "SOLICITUD_CANCELADA",
                "solicitud_id": solicitud_id,
            })
            logger.info(f"[Cancelación] Broadcast SOLICITUD_CANCELADA enviado para #{solicitud_id}.")
        except Exception as e:
            logger.error(f"[Cancelación] Error enviando WS SOLICITUD_CANCELADA: {e}")


    #  Agregar evidencia a solicitud existente
    async def agregar_evidencia(self, data: EvidenciaCreate) -> Evidencia:
        """Agrega una evidencia a una solicitud existente."""
        return await self.evidencia_repo.create(data.model_dump())

    async def obtener_evidencias(self, solicitud_id: int) -> list[Evidencia]:
        return list(await self.evidencia_repo.get_by_solicitud(solicitud_id))


async def verificar_respuesta_mecanico_timeout(solicitud_id: int, asignacion_id: int, timeout_seconds: int = 60):
    """
    Background task to check if the mechanic has responded to the assignment.
    If still PENDIENTE after timeout_seconds, it marks the assignment as RECHAZADA (timeout)
    and resets the request status back to OFERTA_ACEPTADA.
    """
    import logging
    import asyncio
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload
    from app.core.database import AsyncSessionLocal
    from app.models.asignacion import Asignacion, EstadoAsignacion
    from app.models.solicitud_emergencia import SolicitudEmergencia, EstadoSolicitud
    from app.models.empleado import Empleado
    from app.models.taller import Taller, Sucursal
    from app.models.admin import Admin
    from app.services.notificacion_service import NotificacionService

    logger = logging.getLogger(__name__)
    logger.info(f"[Background Timeout] Iniciando espera de {timeout_seconds} segundos para asignación #{asignacion_id}")
    await asyncio.sleep(timeout_seconds)
    logger.info(f"[Background Timeout] Comprobando respuesta para asignación #{asignacion_id}...")

    async with AsyncSessionLocal() as session:
        try:
            # 1. Obtener asignación con relaciones
            stmt = (
                select(Asignacion)
                .where(Asignacion.id == asignacion_id)
                .options(
                    selectinload(Asignacion.empleado).selectinload(Empleado.usuario),
                    selectinload(Asignacion.solicitud),
                    selectinload(Asignacion.sucursal),
                )
            )
            res = await session.execute(stmt)
            asignacion = res.scalar_one_or_none()
            
            if not asignacion:
                logger.info(f"[Background Timeout] Asignación #{asignacion_id} ya no existe.")
                return

            if asignacion.estado != EstadoAsignacion.PENDIENTE:
                logger.info(f"[Background Timeout] El mecánico ya respondió o no está pendiente (estado: {asignacion.estado.value}). No se requiere timeout.")
                return

            # Si sigue pendiente, aplicar timeout
            logger.warning(f"[Background Timeout] Asignación #{asignacion_id} expiró por inactividad. Aplicando rechazo automático por timeout.")
            
            solicitud = asignacion.solicitud
            
            # Cambiar estados
            asignacion.estado = EstadoAsignacion.RECHAZADA
            asignacion.motivo_rechazo = "No respondió a la asignación en el tiempo límite (Timeout)."
            
            # Liberar el mecánico de la asignación
            nombre_mecanico = asignacion.empleado.usuario.nombre if asignacion.empleado and asignacion.empleado.usuario else "El mecánico"
            asignacion.empleado_id = None
            
            # Regresar solicitud a OFERTA_ACEPTADA
            solicitud.estado = EstadoSolicitud.OFERTA_ACEPTADA
            
            await session.commit()
            logger.info(f"[Background Timeout] Asignación #{asignacion_id} rechazada por timeout. Solicitud #{solicitud.id} devuelta a OFERTA_ACEPTADA.")

            # Buscar el ID del administrador de la sucursal
            stmt_admin = (
                select(Admin.usuario_id)
                .join(Taller, Admin.id == Taller.admin_id)
                .join(Sucursal, Taller.id == Sucursal.taller_id)
                .where(Sucursal.id == asignacion.sucursal_id)
            )
            res_admin = await session.execute(stmt_admin)
            admin_usuario_id = res_admin.scalar_one_or_none()

            mensaje_admin = (
                f"{nombre_mecanico} no respondió a la asignación para la emergencia #{solicitud.id} a tiempo. "
                f"La solicitud ha sido restablecida a tu radar. Reasigna a otro técnico."
            )

            # Notificar al administrador
            notificacion_service = NotificacionService(session)
            if admin_usuario_id:
                await notificacion_service.enviar_a_usuario(admin_usuario_id, mensaje_admin)
                try:
                    from app.api.v1.endpoints.notificaciones_ws import manager
                    # Enviar mensaje por WS al administrador
                    await manager.send_personal_message(
                        {
                            "type": "MECANICO_RECHAZO",
                            "solicitud_id": solicitud.id,
                            "asignacion_id": asignacion_id,
                            "motivo": "TIMEOUT",
                            "mensaje": mensaje_admin,
                        },
                        str(admin_usuario_id)
                    )
                    logger.info(f"[Background Timeout] WS enviado al administrador {admin_usuario_id}")
                except Exception as ws_err:
                    logger.error(f"[Background Timeout] Error enviando WS al administrador: {ws_err}")

            # Opcional: Notificar al mecánico que su asignación expiró
            if asignacion.empleado and asignacion.empleado.usuario_id:
                mensaje_mecanico = f"La asignación de la emergencia #{solicitud.id} ha expirado por falta de respuesta."
                await notificacion_service.enviar_a_usuario(asignacion.empleado.usuario_id, mensaje_mecanico)
                try:
                    from app.api.v1.endpoints.notificaciones_ws import manager
                    await manager.send_personal_message(
                        {
                            "type": "ASIGNACION_TIMEOUT",
                            "solicitud_id": solicitud.id,
                            "asignacion_id": asignacion_id,
                            "mensaje": mensaje_mecanico,
                        },
                        str(asignacion.empleado.usuario_id)
                    )
                except Exception as ws_err:
                    logger.error(f"[Background Timeout] Error enviando WS al mecánico: {ws_err}")

        except Exception as e:
            await session.rollback()
            logger.error(f"[Background Timeout] Error crítico en verificación de timeout: {e}", exc_info=True)
