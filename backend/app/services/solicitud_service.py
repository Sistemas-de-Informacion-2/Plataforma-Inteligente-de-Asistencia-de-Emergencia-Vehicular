# backend/app/services/solicitud_service.py
"""
Servicio: SolicitudEmergencia — EL ORQUESTADOR DE BASE DE DATOS.
Este servicio coordina la persistencia del flujo de emergencia:
  1. Guardar la solicitud en BD con el estado dictaminado por la IA.
  2. Asociar evidencias.
  3. Guardar el diagnóstico estructurado.
  4. Disparar búsqueda de taller (PostGIS) según la categoría.
"""
import logging
from typing import Any

from geoalchemy2.elements import WKTElement
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.diagnostico_ia import DiagnosticoIA
from app.models.evidencia import Evidencia, TipoEvidencia
from app.models.solicitud_emergencia import SolicitudEmergencia, EstadoSolicitud
from app.repositories.solicitud_repository import SolicitudRepository
from app.repositories.evidencia_repository import EvidenciaRepository
from app.schemas.solicitud_emergencia import SolicitudCreate
from app.schemas.evidencia import EvidenciaCreate
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

    # Crear solicitud con IA pre-procesada
    async def crear_nueva_solicitud_con_ia(
        self,
        solicitud_in: SolicitudCreate,
        evidencias_in: list[EvidenciaCreate],
        diagnostico: dict,
        estado_inicial: str
    ) -> dict[str, Any]:
        
        resultado = {
            "solicitud": None,
            "evidencias": [],
            "diagnostico": None,
            "asignacion_resultado": None,
        }

        # ── Paso 1: Crear la solicitud con el estado calculado ──
        logger.info(f"[Solicitud] Guardando emergencia para cliente {solicitud_in.cliente_id}")

        solicitud_data = solicitud_in.model_dump()
        
        # Mapeamos el string de estado a nuestro Enum de SQLAlchemy
        try:
            solicitud_data["estado"] = EstadoSolicitud(estado_inicial)
        except ValueError:
            # Fallback seguro si el estado no coincide exactamente
            solicitud_data["estado"] = EstadoSolicitud.PENDIENTE

        # Generar geometría PostGIS
        solicitud_data["ubicacion"] = WKTElement(
            f"POINT({solicitud_in.longitud} {solicitud_in.latitud})", srid=4326
        )

        solicitud = await self.repo.create(solicitud_data)
        resultado["solicitud"] = solicitud

        # ── Paso 2: Guardar evidencias ──
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

        # ── Paso 3: Guardar el Diagnóstico Estructurado ──
        # Mapeamos el JSON de Gemini a las columnas de tu BD actual
        nuevo_diagnostico = DiagnosticoIA(
            solicitud_id=solicitud.id,
            problema_detectado=diagnostico.get("resumen", "Problema desconocido"),
            nivel_gravedad=diagnostico.get("nivel_gravedad", "MEDIO"), # Guardamos la gravedad real aquí
            prioridad=diagnostico.get("prioridad", "MEDIA"),
            costo_estimado_ia=0.0, # Ya no calculamos precios con IA
            # Si en el futuro agregas la columna 'confianza' a tu BD, iría aquí:
            # confianza=diagnostico.get("confianza", 0.0)
        )
        self.session.add(nuevo_diagnostico)
        await self.session.flush()
        await self.session.refresh(nuevo_diagnostico)
        resultado["diagnostico"] = nuevo_diagnostico

        # ── Paso 4: Auto-asignación con PostGIS (Siempre buscar ayuda) ──
        if estado_inicial == "PENDIENTE_ASIGNACION" or estado_inicial == EstadoSolicitud.PENDIENTE.value:
            categoria_ia = diagnostico.get("categoria", "OTRO")
        else:
            # Fallback if IA didn't trust the image/audio
            categoria_ia = "GENERAL"

        logger.info(f"[Asignación] Buscando taller para la categoría: {categoria_ia} (Estado inicial: {estado_inicial})")
        
        asignacion_resultado = await self.asignacion_service.buscar_mejor_taller(
            solicitud_id=solicitud.id,
            latitud_incidente=solicitud.latitud,
            longitud_incidente=solicitud.longitud,
            tipo_problema=categoria_ia,
        )
        resultado["asignacion_resultado"] = asignacion_resultado

        # Si encontró taller, actualizamos a EN_PROCESO
        if asignacion_resultado and asignacion_resultado.get("sucursal"):
            await self.repo.actualizar_estado(solicitud.id, EstadoSolicitud.EN_PROCESO)

            # ── Emisión de Eventos WebSocket ──
            tecnico = asignacion_resultado.get("tecnico_asignado")
            if tecnico:
                from app.api.v1.endpoints.notificaciones_ws import manager
                evento_ws = {
                    "type": "NUEVA_ASIGNACION",
                    "solicitud_id": solicitud.id,
                    "distancia": asignacion_resultado.get("distancia_km"),
                    "eta": asignacion_resultado.get("tiempo_estimado")
                }
                # Notificar al Técnico asignado
                await manager.send_personal_message(evento_ws, str(tecnico.usuario_id))
                # Notificar al Cliente
                await manager.send_personal_message(evento_ws, str(solicitud.cliente_id))

        # ── Paso 5: Notificar al cliente ──────────────────────
        await self.notificacion_service.enviar_a_usuario(
            usuario_id=solicitud.cliente_id,
            mensaje=(
                f"Tu solicitud de emergencia #{solicitud.id} ha sido registrada. "
                f"Estado: {solicitud.estado.value}. "
                "Estamos buscando ayuda para ti."
            ),
        )
        return resultado

    #  Consultas
    async def obtener_por_id(self, solicitud_id: int) -> SolicitudEmergencia | None:
        return await self.repo.get_by_id(solicitud_id)

    async def obtener_detallada(
        self, solicitud_id: int
    ) -> SolicitudEmergencia | None:
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

    async def listar_pendientes(
        self, skip: int = 0, limit: int = 100
    ) -> list[SolicitudEmergencia]:
        return list(await self.repo.get_pendientes(skip=skip, limit=limit))

    async def listar_todas(
        self, skip: int = 0, limit: int = 100
    ) -> list[SolicitudEmergencia]:
        return list(await self.repo.get_all(skip=skip, limit=limit))

    #  Actualización de estado
    async def actualizar_estado(
        self,
        solicitud_id: int,
        nuevo_estado: EstadoSolicitud,
    ) -> SolicitudEmergencia | None:
        """Actualiza el estado y notifica al cliente."""
        solicitud = await self.repo.actualizar_estado(solicitud_id, nuevo_estado)

        if solicitud:
            mensajes_estado = {
                EstadoSolicitud.EN_PROCESO: "Un taller ha aceptado tu solicitud y un técnico va en camino.",
                EstadoSolicitud.ATENDIDO: "Tu solicitud ha sido atendida. ¡Gracias por usar nuestra plataforma!",
                EstadoSolicitud.CANCELADO: "Tu solicitud ha sido cancelada.",
            }
            mensaje = mensajes_estado.get(
                nuevo_estado,
                f"Tu solicitud #{solicitud_id} cambió a estado: {nuevo_estado.value}",
            )
            await self.notificacion_service.enviar_a_usuario(
                usuario_id=solicitud.cliente_id,
                mensaje=mensaje,
            )

        return solicitud

    #  Agregar evidencia a solicitud existente
    async def agregar_evidencia(
        self, data: EvidenciaCreate
    ) -> Evidencia:
        """Agrega una evidencia a una solicitud existente."""
        return await self.evidencia_repo.create(data.model_dump())

    async def obtener_evidencias(
        self, solicitud_id: int
    ) -> list[Evidencia]:
        return list(await self.evidencia_repo.get_by_solicitud(solicitud_id))

    #  Métodos internos
    async def _ejecutar_diagnostico_ia(
        self,
        solicitud: SolicitudEmergencia,
        evidencias_data: list[EvidenciaCreate] | None = None,
    ) -> DiagnosticoIA:
        """
        Ejecuta los módulos de IA sobre las evidencias y genera
        un diagnóstico que se guarda en BD.
        """
        logger.info(f"[IA] Procesando evidencias para solicitud #{solicitud.id}")

        resultado_audio = None
        resultado_imagen = None

        if evidencias_data:
            for ev in evidencias_data:
                if ev.tipo == TipoEvidencia.AUDIO:
                    resultado_audio = await self.ia_service.procesar_audio(ev.url)
                    logger.info(
                        f"[IA] Audio procesado → categoría: "
                        f"{resultado_audio.get('categoria_detectada')}"
                    )

                elif ev.tipo == TipoEvidencia.IMAGEN:
                    resultado_imagen = await self.ia_service.clasificar_imagen(ev.url)
                    logger.info(
                        f"[IA] Imagen clasificada → categoría: "
                        f"{resultado_imagen.get('categoria')}, "
                        f"confianza: {resultado_imagen.get('confianza')}"
                    )

        # Generar resumen/diagnóstico combinando todas las fuentes
        resumen = await self.ia_service.generar_resumen_diagnostico(
            descripcion_usuario=solicitud.descripcion,
            resultado_audio=resultado_audio,
            resultado_imagen=resultado_imagen,
        )

        # Guardar en BD
        diagnostico = DiagnosticoIA(
            problema_detectado=resumen["problema_detectado"],
            nivel_gravedad=resumen["nivel_gravedad"],
            prioridad=resumen["prioridad"],
            costo_estimado_ia=resumen.get("costo_estimado_ia"),
            solicitud_id=solicitud.id,
        )
        self.session.add(diagnostico)
        await self.session.flush()
        await self.session.refresh(diagnostico)

        logger.info(
            f"[IA] Diagnóstico #{diagnostico.id} generado: "
            f"{resumen['nivel_gravedad'].value} / {resumen['prioridad'].value}"
        )

        return diagnostico

    async def _auto_asignar(
        self,
        solicitud: SolicitudEmergencia,
        diagnostico: DiagnosticoIA,
    ) -> dict[str, Any]:
        """Llama al motor de asignación con los datos del diagnóstico."""
        # Extraer metadata del diagnóstico (generada por IAService)
        tipo_problema = getattr(diagnostico, "_servicio_requerido", "Diagnóstico general")

        # Si no tenemos la metadata, inferir del problema detectado
        if tipo_problema == "Diagnóstico general" and diagnostico.problema_detectado:
            tipo_problema = diagnostico.problema_detectado.split("—")[0].strip()

        logger.info(
            f"[Asignación] Auto-asignando para solicitud #{solicitud.id}, "
            f"tipo: '{tipo_problema}'"
        )

        return await self.asignacion_service.buscar_mejor_taller(
            solicitud_id=solicitud.id,
            latitud_incidente=solicitud.latitud,
            longitud_incidente=solicitud.longitud,
            tipo_problema=tipo_problema,
        )
