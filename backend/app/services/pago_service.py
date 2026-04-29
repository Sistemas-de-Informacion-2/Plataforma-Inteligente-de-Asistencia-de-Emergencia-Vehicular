# backend/app/services/pago_service.py
"""
Servicio: Pagos.
Gestiona la creación de pagos, integración con Stripe, generación de QR
y sistema de deuda por comisiones no pagadas en efectivo.
"""
import io
import logging
from typing import Optional

import qrcode
import stripe
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.models.admin import Admin
from app.models.asignacion import Asignacion
from app.models.orden_trabajo import OrdenTrabajo, EstadoOrden
from app.models.pago import Pago, EstadoPago, TipoPago
from app.models.taller import Sucursal, Taller

logger = logging.getLogger(__name__)

# Límite de deuda en Bs antes de bloquear al admin
LIMITE_DEUDA_BS = 150.0


class PagoService:
    def __init__(self, session: AsyncSession):
        self.session = session
        settings = get_settings()
        if settings.STRIPE_SECRET_KEY:
            stripe.api_key = settings.STRIPE_SECRET_KEY

    async def _notificar_deuda(self, admin_id: int, nueva_deuda: float):
        """Notifica por WebSocket al administrador sobre su nueva deuda."""
        try:
            from sqlalchemy import select
            from app.models.admin import Admin
            
            stmt = select(Admin.usuario_id).where(Admin.id == admin_id)
            result = await self.session.execute(stmt)
            usuario_id = result.scalar_one_or_none()
            
            if usuario_id:
                from app.api.v1.endpoints.notificaciones_ws import manager
                await manager.send_personal_message(
                    {
                        "type": "DEUDA_ACTUALIZADA",
                        "nueva_deuda": float(nueva_deuda)
                    },
                    str(usuario_id)
                )
        except Exception as e:
            logger.error(f"[Pago] Error enviando WS DEUDA_ACTUALIZADA: {e}")

    # ── Crear pago (el admin ingresa el monto post-servicio) ──
    async def crear_pago(
        self,
        solicitud_id: int,
        monto_total: float,
        admin_id: int,
        metodo_pago: str = "APP",
    ) -> dict:
        """
        Crea una OrdenTrabajo + Pago pendiente para una solicitud.
        El admin ingresa el monto después de atender el servicio.
        
        Returns:
            Dict con pago_id, monto_total, comision, monto_taller
        """
        # Buscar la sucursal del admin a partir de la asignación
        stmt = (
            select(Asignacion)
            .where(Asignacion.solicitud_id == solicitud_id)
            .options(selectinload(Asignacion.sucursal))
        )
        result = await self.session.execute(stmt)
        asignacion = result.scalar_one_or_none()

        if not asignacion:
            raise ValueError(f"No existe asignación para la solicitud #{solicitud_id}")

        # Crear orden de trabajo
        orden = OrdenTrabajo(
            solicitud_id=solicitud_id,
            sucursal_id=asignacion.sucursal_id,
            estado=EstadoOrden.COMPLETADA,
        )
        self.session.add(orden)
        await self.session.flush()

        # Calcular comisión 10%
        comision = round(monto_total * 0.10, 2)
        monto_taller = round(monto_total - comision, 2)

        # Crear pago pendiente
        pago = Pago(
            orden_id=orden.id,
            monto_total=monto_total,
            comision=comision,
            monto_taller=monto_taller,
            estado=EstadoPago.PENDIENTE,
        )
        self.session.add(pago)
        await self.session.flush()
        await self.session.refresh(pago)

        logger.info(
            f"[Pago] Creado pago #{pago.id}: total={monto_total}, "
            f"comisión={comision}, taller={monto_taller}"
        )

        # Actualizar el estado de la solicitud a ATENDIDO
        from app.models.solicitud_emergencia import SolicitudEmergencia, EstadoSolicitud
        stmt_upd = select(SolicitudEmergencia).where(SolicitudEmergencia.id == solicitud_id)
        result_upd = await self.session.execute(stmt_upd)
        solicitud_actualizar = result_upd.scalar_one_or_none()
        if solicitud_actualizar:
            solicitud_actualizar.estado = EstadoSolicitud.ATENDIDO

        # Si el admin escogió EFECTIVO o QR, marcamos el pago y sumamos la deuda
        if metodo_pago in ["EFECTIVO", "QR"]:
            pago.estado = EstadoPago.COMPLETADO
            pago.tipo_pago = TipoPago.EFECTIVO if metodo_pago == "EFECTIVO" else TipoPago.QR
            admin = await self.session.get(Admin, admin_id)
            if admin:
                admin.deuda_comision = (admin.deuda_comision or 0) + comision
                logger.info(
                    f"[Pago] {metodo_pago} confirmado en crear_pago. Deuda admin #{admin_id}: "
                    f"Bs. {admin.deuda_comision:.2f} (+{comision:.2f})"
                )
                await self._notificar_deuda(admin_id, admin.deuda_comision)
        else:
            # Notificar al cliente via WS (sólo si es por la APP)
            try:
                stmt_sol = select(SolicitudEmergencia.cliente_id).where(
                    SolicitudEmergencia.id == solicitud_id
                )
                result_sol = await self.session.execute(stmt_sol)
                cliente_id = result_sol.scalar_one_or_none()

                if cliente_id:
                    from app.api.v1.endpoints.notificaciones_ws import manager
                    await manager.send_personal_message(
                        {
                            "type": "PAGO_REQUERIDO",
                            "pago_id": pago.id,
                            "solicitud_id": solicitud_id,
                            "monto_total": monto_total,
                            "comision": comision,
                            "monto_taller": monto_taller,
                            "mensaje": f"El servicio ha finalizado. Monto total: Bs. {monto_total:.2f}",
                        },
                        str(cliente_id)
                    )
            except Exception as e:
                logger.error(f"[Pago] Error WS PAGO_REQUERIDO: {e}")

        await self.session.commit()

        return {
            "pago_id": pago.id,
            "orden_id": orden.id,
            "monto_total": monto_total,
            "comision": comision,
            "monto_taller": monto_taller,
        }

    # ── Stripe Checkout ──────────────────────────────────────
    async def crear_checkout_stripe(self, pago_id: int) -> str:
        """
        Crea una Stripe Checkout Session para un pago.
        Returns: URL de la sesión de checkout.
        """
        pago = await self.session.get(Pago, pago_id)
        if not pago or pago.estado != EstadoPago.PENDIENTE:
            raise ValueError("Pago no encontrado o no está pendiente.")

        settings = get_settings()
        if not settings.STRIPE_SECRET_KEY:
            raise ValueError("Stripe no configurado en el servidor.")

        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[{
                "price_data": {
                    "currency": "bob",  # Bolivianos
                    "product_data": {
                        "name": f"Servicio de Emergencia Vehicular - Pago #{pago_id}",
                        "description": f"Monto: Bs. {pago.monto_total:.2f} (incluye Bs. {pago.comision:.2f} de comisión de plataforma)",
                    },
                    "unit_amount": int(pago.monto_total * 100),  # En centavos
                },
                "quantity": 1,
            }],
            mode="payment",
            success_url=f"{settings.BACKEND_URL}{settings.API_V1_PREFIX}/pagos/{pago_id}/exito?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=f"{settings.BACKEND_URL}{settings.API_V1_PREFIX}/pagos/{pago_id}/cancelado",
            metadata={
                "pago_id": str(pago_id),
            },
        )

        # Guardar el ID de la sesión
        pago.stripe_session_id = session.id
        pago.tipo_pago = TipoPago.TARJETA
        await self.session.commit()

        logger.info(f"[Stripe] Checkout Session creada: {session.id} para pago #{pago_id}")
        return session.url

    # ── Confirmar pago Stripe (webhook o redirect) ──────────
    async def confirmar_pago_stripe(self, session_id: str) -> bool:
        """Confirma que un pago Stripe fue exitoso."""
        stmt = select(Pago).where(Pago.stripe_session_id == session_id)
        result = await self.session.execute(stmt)
        pago = result.scalar_one_or_none()

        if not pago:
            logger.warning(f"[Stripe] No se encontró pago con session_id: {session_id}")
            return False

        checkout_session = stripe.checkout.Session.retrieve(session_id)
        if checkout_session.payment_status == "paid":
            pago.estado = EstadoPago.COMPLETADO
            pago.stripe_payment_intent_id = checkout_session.payment_intent
            await self.session.commit()
            logger.info(f"[Stripe] ✅ Pago #{pago.id} confirmado como COMPLETADO.")
            return True

        return False

    # ── Pago en Efectivo ─────────────────────────────────────
    async def marcar_pago_efectivo(self, pago_id: int, admin_id: int) -> bool:
        """
        Marca un pago como cobrado en efectivo.
        Carga la comisión (10%) como deuda al admin.
        """
        pago = await self.session.get(Pago, pago_id)
        if not pago or pago.estado != EstadoPago.PENDIENTE:
            return False

        pago.estado = EstadoPago.COMPLETADO
        pago.tipo_pago = TipoPago.EFECTIVO

        # Cargar deuda de comisión al admin
        admin = await self.session.get(Admin, admin_id)
        if admin:
            admin.deuda_comision = (admin.deuda_comision or 0) + pago.comision
            logger.info(
                f"[Pago] Efectivo confirmado. Deuda admin #{admin_id}: "
                f"Bs. {admin.deuda_comision:.2f} (+{pago.comision:.2f})"
            )
            await self._notificar_deuda(admin_id, admin.deuda_comision)

        await self.session.commit()
        return True

    # ── Verificar si admin puede aceptar solicitudes ──────
    async def admin_puede_aceptar(self, admin_id: int) -> bool:
        """Verifica si el admin no ha excedido el límite de deuda."""
        admin = await self.session.get(Admin, admin_id)
        if not admin:
            return False
        return (admin.deuda_comision or 0) < LIMITE_DEUDA_BS

    async def obtener_qr_url(self, pago_id: int) -> Optional[str]:
        """
        Retorna la URL del QR del admin, si existe.
        """
        pago = await self.session.get(Pago, pago_id)
        if not pago:
            raise ValueError("Pago no encontrado.")

        # Buscar orden -> asignacion -> sucursal -> taller -> admin
        stmt = (
            select(Admin.qr_imagen_url)
            .select_from(Pago)
            .join(OrdenTrabajo, OrdenTrabajo.id == Pago.orden_id)
            .join(Sucursal, Sucursal.id == OrdenTrabajo.sucursal_id)
            .join(Taller, Taller.id == Sucursal.taller_id)
            .join(Admin, Admin.id == Taller.admin_id)
            .where(Pago.id == pago_id)
        )
        result = await self.session.execute(stmt)
        qr_url = result.scalar_one_or_none()
        
        return qr_url

    async def confirmar_pago_qr(self, pago_id: int) -> bool:
        """
        El cliente marca el QR como pagado.
        Carga la comisión (10%) como deuda al admin (igual que efectivo).
        """
        pago = await self.session.get(Pago, pago_id)
        if not pago or pago.estado != EstadoPago.PENDIENTE:
            return False

        pago.estado = EstadoPago.COMPLETADO
        pago.tipo_pago = TipoPago.QR

        # Cargar deuda de comisión al admin
        stmt = (
            select(Admin)
            .select_from(Pago)
            .join(OrdenTrabajo, OrdenTrabajo.id == Pago.orden_id)
            .join(Sucursal, Sucursal.id == OrdenTrabajo.sucursal_id)
            .join(Taller, Taller.id == Sucursal.taller_id)
            .join(Admin, Admin.id == Taller.admin_id)
            .where(Pago.id == pago_id)
        )
        result = await self.session.execute(stmt)
        admin = result.scalar_one_or_none()
        
        if admin:
            admin.deuda_comision = (admin.deuda_comision or 0) + pago.comision
            logger.info(
                f"[Pago] QR confirmado. Deuda admin #{admin.id}: "
                f"Bs. {admin.deuda_comision:.2f} (+{pago.comision:.2f})"
            )
            await self._notificar_deuda(admin.id, admin.deuda_comision)

        await self.session.commit()
        return True

    async def confirmar_pago_efectivo_cliente(self, pago_id: int) -> bool:
        """
        El cliente confirma que pagará en efectivo al llegar el mecánico.
        Carga la comisión (10%) como deuda al admin (igual que QR).
        """
        pago = await self.session.get(Pago, pago_id)
        if not pago or pago.estado != EstadoPago.PENDIENTE:
            return False

        pago.estado = EstadoPago.COMPLETADO
        pago.tipo_pago = TipoPago.EFECTIVO

        # Cargar deuda de comisión al admin
        stmt = (
            select(Admin)
            .select_from(Pago)
            .join(OrdenTrabajo, OrdenTrabajo.id == Pago.orden_id)
            .join(Sucursal, Sucursal.id == OrdenTrabajo.sucursal_id)
            .join(Taller, Taller.id == Sucursal.taller_id)
            .join(Admin, Admin.id == Taller.admin_id)
            .where(Pago.id == pago_id)
        )
        result = await self.session.execute(stmt)
        admin = result.scalar_one_or_none()
        
        if admin:
            admin.deuda_comision = (admin.deuda_comision or 0) + pago.comision
            logger.info(
                f"[Pago] Efectivo confirmado por CLIENTE. Deuda admin #{admin.id}: "
                f"Bs. {admin.deuda_comision:.2f} (+{pago.comision:.2f})"
            )
            await self._notificar_deuda(admin.id, admin.deuda_comision)

        await self.session.commit()
        return True

    # ── Obtener detalle de un pago ───────────────────────────
    async def obtener_pago(self, pago_id: int) -> Optional[Pago]:
        return await self.session.get(Pago, pago_id)
