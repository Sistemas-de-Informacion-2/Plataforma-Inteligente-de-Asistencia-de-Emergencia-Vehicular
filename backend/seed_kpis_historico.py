# backend/seed_kpis_historico.py
"""
Seed de datos históricos B2B para dashboards KPI.
Crea 3 talleres competidores en Santa Cruz de la Sierra con sus admins,
sucursales, mecánicos y 18 solicitudes históricas distribuidas en 2026.

NO toca el seed.py original (que crea al SUPER_ADMIN).
Ejecutar desde /backend:  python seed_kpis_historico.py
"""

import asyncio
from datetime import datetime, timezone, timedelta

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password
from app.models.rol import Rol, UsuarioRol
from app.models.usuario import Usuario
from app.models.vehiculo import Vehiculo
from app.models.taller import Taller, Sucursal
from app.models.admin import Admin
from app.models.empleado import Empleado
from app.models.solicitud_emergencia import SolicitudEmergencia, EstadoSolicitud
from app.models.diagnostico_ia import DiagnosticoIA, NivelGravedad, Prioridad
from app.models.sos_notificacion_sucursal import SosNotificacionSucursal
from app.models.puja import Puja, EstadoPuja
from app.models.asignacion import Asignacion, EstadoAsignacion
from app.models.orden_trabajo import OrdenTrabajo, DetalleOrden, EstadoOrden


# ── Helpers ───────────────────────────────────────────────────────────────────

def _utc(year: int, month: int, day: int, hour: int = 10, minute: int = 0) -> datetime:
    return datetime(year, month, day, hour, minute, 0, tzinfo=timezone.utc)


async def _rol(session, nombre: str) -> Rol:
    res = await session.execute(select(Rol).where(Rol.nombre == nombre))
    r = res.scalar_one_or_none()
    if not r:
        r = Rol(nombre=nombre)
        session.add(r)
        await session.flush()
    return r


async def _usuario(session, email: str, nombre: str, ci: str) -> Usuario:
    res = await session.execute(select(Usuario).where(Usuario.email == email))
    u = res.scalar_one_or_none()
    if not u:
        u = Usuario(
            nombre=nombre,
            email=email,
            password=hash_password("kpi123"),
            telefono="70000000",
            ci=ci,
        )
        session.add(u)
        await session.flush()
    return u


async def _asignar_rol(session, usuario: Usuario, rol: Rol) -> None:
    res = await session.execute(
        select(UsuarioRol).where(
            UsuarioRol.usuario_id == usuario.id,
            UsuarioRol.rol_id == rol.id,
        )
    )
    if not res.scalar_one_or_none():
        session.add(UsuarioRol(usuario_id=usuario.id, rol_id=rol.id))


async def _admin_profile(session, usuario: Usuario) -> Admin:
    res = await session.execute(select(Admin).where(Admin.usuario_id == usuario.id))
    a = res.scalar_one_or_none()
    if not a:
        a = Admin(usuario_id=usuario.id)
        session.add(a)
        await session.flush()
    return a


async def _taller(session, nombre: str, admin: Admin) -> Taller:
    res = await session.execute(select(Taller).where(Taller.nombre == nombre))
    t = res.scalar_one_or_none()
    if not t:
        t = Taller(nombre=nombre, admin_id=admin.id)
        session.add(t)
        await session.flush()
    return t


async def _sucursal(session, nombre: str, direccion: str, lat: float, lon: float,
                    telefono: str, taller_id: int) -> Sucursal:
    res = await session.execute(select(Sucursal).where(Sucursal.nombre == nombre))
    s = res.scalar_one_or_none()
    if not s:
        s = Sucursal(
            nombre=nombre,
            direccion=direccion,
            latitud=lat,
            longitud=lon,
            telefono=telefono,
            taller_id=taller_id,
        )
        session.add(s)
        await session.flush()
    return s


async def _empleado(session, usuario: Usuario, sucursal: Sucursal,
                    especialidad: str, lat: float, lon: float) -> Empleado:
    res = await session.execute(select(Empleado).where(Empleado.usuario_id == usuario.id))
    e = res.scalar_one_or_none()
    if not e:
        e = Empleado(
            especialidad=especialidad,
            disponible=True,
            latitud=lat,
            longitud=lon,
            usuario_id=usuario.id,
            sucursal_id=sucursal.id,
        )
        session.add(e)
        await session.flush()
    return e


async def _vehiculo(session, placa: str, marca: str, modelo: str,
                    anio: int, usuario: Usuario) -> Vehiculo:
    res = await session.execute(select(Vehiculo).where(Vehiculo.placa == placa))
    v = res.scalar_one_or_none()
    if not v:
        v = Vehiculo(marca=marca, modelo=modelo, anio=anio,
                     placa=placa, usuario_id=usuario.id)
        session.add(v)
        await session.flush()
    return v


# ── Seed principal ────────────────────────────────────────────────────────────

async def seed_kpis():
    print("⏳ Iniciando seed B2B histórico KPI — Santa Cruz de la Sierra...")

    async with AsyncSessionLocal() as session:

        # ── ROLES ─────────────────────────────────────────────────────────────
        rol_cliente  = await _rol(session, "CLIENTE")
        rol_mecanico = await _rol(session, "MECANICO")
        rol_admin_t  = await _rol(session, "ADMIN_TALLER")
        await session.flush()

        # ── ADMINS DE TALLER (3 usuarios + perfil Admin) ───────────────────────
        u_alfa  = await _usuario(session, "admin_alfa@test.com",  "Roberto Vargas Alfa",  "5000001")
        u_beta  = await _usuario(session, "admin_beta@test.com",  "Marcela Suárez Beta",  "5000002")
        u_gamma = await _usuario(session, "admin_gamma@test.com", "Ernesto Paz Gamma",    "5000003")

        for u in [u_alfa, u_beta, u_gamma]:
            await _asignar_rol(session, u, rol_admin_t)
        await session.flush()

        adm_alfa  = await _admin_profile(session, u_alfa)
        adm_beta  = await _admin_profile(session, u_beta)
        adm_gamma = await _admin_profile(session, u_gamma)

        # ── TALLERES ───────────────────────────────────────────────────────────
        t_alfa  = await _taller(session, "Taller Alfa",  adm_alfa)
        t_beta  = await _taller(session, "Taller Beta",  adm_beta)
        t_gamma = await _taller(session, "Taller Gamma", adm_gamma)

        # ── SUCURSALES (2 por taller, coordenadas Santa Cruz) ─────────────────
        # Lat: -17.75 a -17.85 | Lon: -63.15 a -63.22
        suc_alfa_n = await _sucursal(session,
            "Alfa Norte", "Av. Banzer km 3, Santa Cruz", -17.752, -63.160, "33110011", t_alfa.id)
        suc_alfa_s = await _sucursal(session,
            "Alfa Sur",   "Av. Santos Dumont 480, Santa Cruz", -17.838, -63.198, "33110022", t_alfa.id)

        suc_beta_c = await _sucursal(session,
            "Beta Centro", "Calle Libertad 120, Santa Cruz", -17.783, -63.182, "33220011", t_beta.id)
        suc_beta_e = await _sucursal(session,
            "Beta Este",   "Av. Roca y Coronado 900, Santa Cruz", -17.769, -63.155, "33220022", t_beta.id)

        suc_gamma_o = await _sucursal(session,
            "Gamma Oeste", "Av. Cristóbal de Mendoza 350, Santa Cruz", -17.801, -63.218, "33330011", t_gamma.id)
        suc_gamma_s = await _sucursal(session,
            "Gamma Sur",   "Carretera al Valle km 2, Santa Cruz", -17.847, -63.207, "33330022", t_gamma.id)

        await session.flush()

        # ── MECÁNICOS (1 por sucursal) ─────────────────────────────────────────
        u_mec = []
        mec_data = [
            ("mec_alfa_n@test.com", "Luis Torrico",    "7000001", suc_alfa_n,  "Electricidad",         -17.753, -63.161),
            ("mec_alfa_s@test.com", "Fátima Daza",     "7000002", suc_alfa_s,  "Mecánica general",     -17.839, -63.199),
            ("mec_beta_c@test.com", "Jorge Orellana",  "7000003", suc_beta_c,  "Motor y transmisión",  -17.784, -63.183),
            ("mec_beta_e@test.com", "Carla Mendez",    "7000004", suc_beta_e,  "Frenos y suspensión",  -17.770, -63.156),
            ("mec_gamma_o@test.com","Pedro Salvatierra","7000005", suc_gamma_o, "Remolque",             -17.802, -63.219),
            ("mec_gamma_s@test.com","Andrea Vaca",     "7000006", suc_gamma_s,  "Llantas y alineación", -17.848, -63.208),
        ]
        empleados = {}
        for email, nombre, ci, suc, esp, lat, lon in mec_data:
            u = await _usuario(session, email, nombre, ci)
            await _asignar_rol(session, u, rol_mecanico)
            await session.flush()
            emp = await _empleado(session, u, suc, esp, lat, lon)
            empleados[suc.nombre] = emp

        # ── CLIENTES + VEHÍCULOS ───────────────────────────────────────────────
        cli1 = await _usuario(session, "cliente1_scz@test.com", "Ana Quispe",    "6000001")
        cli2 = await _usuario(session, "cliente2_scz@test.com", "Bruno Mamani",  "6000002")
        cli3 = await _usuario(session, "cliente3_scz@test.com", "Sandra Flores", "6000003")
        for c in [cli1, cli2, cli3]:
            await _asignar_rol(session, c, rol_cliente)
        await session.flush()

        veh1 = await _vehiculo(session, "SCZ-001", "Toyota",  "Corolla",  2020, cli1)
        veh2 = await _vehiculo(session, "SCZ-002", "Honda",   "Civic",    2019, cli2)
        veh3 = await _vehiculo(session, "SCZ-003", "Chevrolet","Aveo",    2018, cli3)
        veh4 = await _vehiculo(session, "SCZ-004", "Hyundai", "Accent",   2021, cli1)
        await session.flush()

        # ── SOLICITUDES HISTÓRICAS ─────────────────────────────────────────────
        # Cada entrada: (desc, lat, lon, cliente, veh, t0, estado,
        #                categoria, gravedad, prioridad, costo_ia,
        #                suc_puja_principal, suc_puja_rival,
        #                precio_principal, precio_rival, eta_min,
        #                costo_real_orden)   ← None si no es FINALIZADO

        SOLICITUDES = [
            # ── TALLER ALFA (sucursales alfa_n y alfa_s) ──────────────────────
            (
                "Batería agotada, auto no enciende en zona norte",
                -17.758, -63.163, cli1, veh1, _utc(2026, 1, 10, 8, 0),
                EstadoSolicitud.FINALIZADO, "Batería",
                NivelGravedad.MEDIO, Prioridad.ALTA,
                150.0, suc_alfa_n, suc_beta_c, 170.0, 190.0, 12, 160.0,
            ),
            (
                "Motor sobrecalentado, humo saliendo por radiador",
                -17.761, -63.169, cli2, veh2, _utc(2026, 1, 25, 11, 30),
                EstadoSolicitud.FINALIZADO, "Motor",
                NivelGravedad.GRAVE, Prioridad.URGENTE,
                600.0, suc_alfa_n, suc_gamma_o, 650.0, 700.0, 18, 580.0,
            ),
            (
                "Llanta desinflada sin gato de repuesto en av. Banzer",
                -17.754, -63.158, cli3, veh3, _utc(2026, 2, 5, 15, 0),
                EstadoSolicitud.FINALIZADO, "Llantas",
                NivelGravedad.LEVE, Prioridad.MEDIA,
                70.0, suc_alfa_n, suc_beta_e, 85.0, 95.0, 10, 75.0,
            ),
            (
                "Frenos sin respuesta, pedal al piso en centro norte",
                -17.762, -63.167, cli1, veh4, _utc(2026, 3, 12, 9, 15),
                EstadoSolicitud.FINALIZADO, "Frenos",
                NivelGravedad.CRITICO, Prioridad.URGENTE,
                850.0, suc_alfa_s, suc_beta_c, 900.0, 920.0, 20, 890.0,
            ),
            (
                "Luces delanteras fundidas, no puedo circular de noche",
                -17.841, -63.200, cli2, veh2, _utc(2026, 4, 3, 22, 0),
                EstadoSolicitud.CANCELADO, "Sistema eléctrico",
                NivelGravedad.LEVE, Prioridad.BAJA,
                110.0, suc_alfa_s, suc_gamma_s, None, None, None, None,
            ),
            (
                "Transmisión automática patinando, no entra segunda",
                -17.836, -63.196, cli3, veh3, _utc(2026, 5, 8, 13, 45),
                EstadoSolicitud.FINALIZADO, "Transmisión",
                NivelGravedad.GRAVE, Prioridad.ALTA,
                750.0, suc_alfa_s, suc_gamma_o, 800.0, 830.0, 25, 720.0,
            ),

            # ── TALLER BETA (sucursales beta_c y beta_e) ──────────────────────
            (
                "Batería descargada en plena avenida Santos Dumont",
                -17.780, -63.184, cli1, veh1, _utc(2026, 1, 18, 7, 30),
                EstadoSolicitud.FINALIZADO, "Batería",
                NivelGravedad.MEDIO, Prioridad.ALTA,
                160.0, suc_beta_c, suc_alfa_n, 175.0, 195.0, 14, 155.0,
            ),
            (
                "Choque leve, vehículo no arranca necesita remolque",
                -17.785, -63.180, cli2, veh2, _utc(2026, 2, 20, 16, 0),
                EstadoSolicitud.FINALIZADO, "Remolque",
                NivelGravedad.GRAVE, Prioridad.URGENTE,
                320.0, suc_beta_c, suc_gamma_o, 350.0, 370.0, 22, 310.0,
            ),
            (
                "Suspensión rota, ruido fuerte al girar volante",
                -17.772, -63.157, cli3, veh3, _utc(2026, 3, 7, 10, 0),
                EstadoSolicitud.FINALIZADO, "Suspensión",
                NivelGravedad.MEDIO, Prioridad.MEDIA,
                420.0, suc_beta_e, suc_alfa_s, 450.0, 480.0, 16, 440.0,
            ),
            (
                "Alternador dañado, batería no carga en zona este",
                -17.766, -63.154, cli1, veh4, _utc(2026, 4, 15, 14, 20),
                EstadoSolicitud.CANCELADO, "Sistema eléctrico",
                NivelGravedad.MEDIO, Prioridad.MEDIA,
                280.0, suc_beta_e, suc_gamma_s, None, None, None, None,
            ),
            (
                "Motor no arranca, posible falla en inyectores zona este",
                -17.770, -63.156, cli2, veh2, _utc(2026, 5, 2, 8, 10),
                EstadoSolicitud.FINALIZADO, "Motor",
                NivelGravedad.GRAVE, Prioridad.URGENTE,
                500.0, suc_beta_e, suc_alfa_n, 540.0, 570.0, 19, 510.0,
            ),
            (
                "Llanta reventada en doble vía La Guardia",
                -17.768, -63.159, cli3, veh3, _utc(2026, 5, 18, 12, 0),
                EstadoSolicitud.FINALIZADO, "Llantas",
                NivelGravedad.LEVE, Prioridad.MEDIA,
                65.0, suc_beta_c, suc_gamma_o, 80.0, 90.0, 11, 70.0,
            ),

            # ── TALLER GAMMA (sucursales gamma_o y gamma_s) ───────────────────
            (
                "Batería muerta frente al mercado Los Pozos",
                -17.803, -63.219, cli1, veh1, _utc(2026, 2, 12, 9, 0),
                EstadoSolicitud.FINALIZADO, "Batería",
                NivelGravedad.MEDIO, Prioridad.ALTA,
                145.0, suc_gamma_o, suc_beta_c, 160.0, 180.0, 13, 150.0,
            ),
            (
                "Frenos desgastados, chirrido fuerte en zona oeste",
                -17.799, -63.215, cli2, veh2, _utc(2026, 3, 22, 17, 30),
                EstadoSolicitud.FINALIZADO, "Frenos",
                NivelGravedad.MEDIO, Prioridad.ALTA,
                380.0, suc_gamma_o, suc_alfa_s, 410.0, 430.0, 17, 395.0,
            ),
            (
                "Remolque urgente, accidente en carretera al Valle",
                -17.849, -63.209, cli3, veh3, _utc(2026, 4, 8, 20, 0),
                EstadoSolicitud.FINALIZADO, "Remolque",
                NivelGravedad.GRAVE, Prioridad.URGENTE,
                340.0, suc_gamma_s, suc_beta_e, 370.0, 400.0, 24, 355.0,
            ),
            (
                "Aire acondicionado sin gas, compresor dañado zona sur",
                -17.845, -63.205, cli1, veh4, _utc(2026, 4, 28, 11, 0),
                EstadoSolicitud.CANCELADO, "Sistema eléctrico",
                NivelGravedad.LEVE, Prioridad.BAJA,
                200.0, suc_gamma_s, suc_alfa_n, None, None, None, None,
            ),
            (
                "Motor ruidoso, posible daño en cadena de distribución",
                -17.843, -63.203, cli2, veh2, _utc(2026, 5, 14, 10, 30),
                EstadoSolicitud.FINALIZADO, "Motor",
                NivelGravedad.GRAVE, Prioridad.URGENTE,
                680.0, suc_gamma_s, suc_beta_c, 730.0, 760.0, 21, 660.0,
            ),
            (
                "Fuga de aceite severa debajo del motor zona sur",
                -17.850, -63.210, cli3, veh3, _utc(2026, 5, 25, 8, 0),
                EstadoSolicitud.FINALIZADO, "Motor",
                NivelGravedad.GRAVE, Prioridad.URGENTE,
                450.0, suc_gamma_s, suc_alfa_s, 490.0, 520.0, 23, 430.0,
            ),
        ]

        for idx, row in enumerate(SOLICITUDES, start=1):
            (
                desc, lat, lon, cliente, vehiculo, t0, estado,
                categoria, gravedad, prioridad, costo_ia,
                suc_principal, suc_rival,
                precio_principal, precio_rival, eta_min, costo_real,
            ) = row

            # Idempotencia
            res = await session.execute(
                select(SolicitudEmergencia).where(SolicitudEmergencia.descripcion == desc)
            )
            if res.scalar_one_or_none():
                print(f"   ℹ️  Solicitud {idx:02d} ya existe, omitiendo.")
                continue

            es_finalizado = estado == EstadoSolicitud.FINALIZADO
            t_fin = t0 + timedelta(minutes=120) if es_finalizado else None

            # ── SolicitudEmergencia ───────────────────────────────────────────
            sol = SolicitudEmergencia(
                descripcion=desc,
                latitud=lat,
                longitud=lon,
                estado=estado,
                fecha_creacion=t0,
                fecha_actualizacion=t_fin or t0,
                fecha_finalizacion=t_fin,
                cliente_id=cliente.id,
                vehiculo_id=vehiculo.id,
            )
            session.add(sol)
            await session.flush()

            # ── DiagnosticoIA ─────────────────────────────────────────────────
            diag = DiagnosticoIA(
                problema_detectado=(
                    f"Diagnóstico automático: {desc[:80]}. "
                    f"Categoría: {categoria}."
                ),
                nivel_gravedad=gravedad,
                prioridad=prioridad,
                costo_estimado_ia=costo_ia,
                fecha=t0 + timedelta(minutes=1),
                categoria_incidencia=categoria,
                solicitud_id=sol.id,
            )
            session.add(diag)

            # ── SosNotificaciones ─────────────────────────────────────────────
            t_notif = t0 + timedelta(minutes=3)
            session.add(SosNotificacionSucursal(
                solicitud_id=sol.id, sucursal_id=suc_principal.id,
                fecha_envio=t_notif, respondio=es_finalizado,
            ))
            session.add(SosNotificacionSucursal(
                solicitud_id=sol.id, sucursal_id=suc_rival.id,
                fecha_envio=t_notif, respondio=False,
            ))

            if not es_finalizado:
                await session.flush()
                print(f"   ✅ Solicitud {idx:02d} CANCELADO — {categoria} ({suc_principal.nombre})")
                continue

            # ── Pujas ─────────────────────────────────────────────────────────
            t_aceptacion = t0 + timedelta(minutes=15)
            puja_win = Puja(
                precio_estimado=precio_principal,
                tiempo_llegada_minutos=eta_min,
                estado=EstadoPuja.ACEPTADA,
                fecha=t0 + timedelta(minutes=5),
                fecha_aceptacion=t_aceptacion,
                solicitud_id=sol.id,
                sucursal_id=suc_principal.id,
            )
            puja_lose = Puja(
                precio_estimado=precio_rival,
                tiempo_llegada_minutos=eta_min + 5,
                estado=EstadoPuja.RECHAZADA,
                fecha=t0 + timedelta(minutes=7),
                fecha_aceptacion=None,
                solicitud_id=sol.id,
                sucursal_id=suc_rival.id,
            )
            session.add(puja_win)
            session.add(puja_lose)

            # ── Asignacion ────────────────────────────────────────────────────
            emp = empleados.get(suc_principal.nombre)
            t_asig = t0 + timedelta(minutes=16)
            t_llegada = t_asig + timedelta(minutes=eta_min + 4)
            asig = Asignacion(
                estado=EstadoAsignacion.COMPLETADA,
                fecha=t_asig,
                fecha_aceptacion=t_asig + timedelta(minutes=1),
                fecha_llegada=t_llegada,
                tiempo_estimado_llegada=eta_min,
                solicitud_id=sol.id,
                empleado_id=emp.id if emp else None,
                sucursal_id=suc_principal.id,
            )
            session.add(asig)

            # ── OrdenTrabajo + DetalleOrden (para KPI10) ─────────────────────
            orden = OrdenTrabajo(
                estado=EstadoOrden.COMPLETADA,
                fecha_inicio=t_llegada,
                fecha_fin=t_fin,
                solicitud_id=sol.id,
                sucursal_id=suc_principal.id,
            )
            session.add(orden)
            await session.flush()

            detalle = DetalleOrden(
                descripcion=f"Servicio principal: {categoria}",
                costo=costo_real,
                orden_id=orden.id,
            )
            session.add(detalle)
            await session.flush()

            print(
                f"   ✅ Solicitud {idx:02d} FINALIZADO — {categoria} "
                f"({suc_principal.nombre} | IA:{costo_ia} → Real:{costo_real})"
            )

        await session.commit()
        print("\n🎉 Seed B2B KPI completado exitosamente!")
        print("\n── Credenciales generadas (contraseña: kpi123) ──────────────")
        print("  SUPER_ADMIN (del seed.py original): ver seed.py")
        print("  admin_alfa@test.com   → ADMIN_TALLER — Taller Alfa  (2 sucursales)")
        print("  admin_beta@test.com   → ADMIN_TALLER — Taller Beta  (2 sucursales)")
        print("  admin_gamma@test.com  → ADMIN_TALLER — Taller Gamma (2 sucursales)")
        print("  cliente1_scz@test.com → CLIENTE")
        print("  cliente2_scz@test.com → CLIENTE")
        print("  cliente3_scz@test.com → CLIENTE")


if __name__ == "__main__":
    asyncio.run(seed_kpis())
