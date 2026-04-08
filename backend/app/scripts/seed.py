"""
Script de Semilla (Seed) para la Base de Datos.
Pobla la BD con datos iniciales para pruebas, ubicados en Santa Cruz de la Sierra.
"""

import asyncio
from sqlalchemy import select
from geoalchemy2.elements import WKTElement

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password

# Modelos
from app.models.usuario import Usuario, UsuarioPerfil
from app.models.rol import Rol, Permiso, UsuarioRol
from app.models.admin import Admin
from app.models.empleado import Empleado
from app.models.vehiculo import Vehiculo
from app.models.taller import Taller, Sucursal
from app.models.servicio import Servicio, SucursalServicio


async def clean_database(session):
    """Limpia las tablas antes de poblar para evitar duplicados en PK/UKs."""
    print("[Seed] Limpiando datos existentes...")
    
    # Simplemente eliminamos los usuarios principales (y CASCADE hará el resto)
    result = await session.execute(select(Usuario))
    usuarios = result.scalars().all()
    for u in usuarios:
        await session.delete(u)
        
    result = await session.execute(select(Servicio))
    servicios = result.scalars().all()
    for s in servicios:
        await session.delete(s)

    result = await session.execute(select(Rol))
    roles = result.scalars().all()
    for r in roles:
        await session.delete(r)
        
    await session.commit()
    print("[Seed] Base de datos limpia.")


async def seed_data():
    async with AsyncSessionLocal() as session:
        try:
            await clean_database(session)

            print("[Seed] Creando Roles...")
            rol_cliente = Rol(nombre="CLIENTE")
            rol_admin = Rol(nombre="ADMIN_TALLER")
            rol_tecnico = Rol(nombre="TECNICO")
            session.add_all([rol_cliente, rol_admin, rol_tecnico])
            await session.flush()

            print("[Seed] Creando Usuarios Base...")
            # 1. Cliente
            cliente = Usuario(
                nombre="Carlos",
                email="carlos.cliente@test.com",
                password=hash_password("password123"),
                telefono="77712345",
                ci="8888888",
            )
            cliente.perfil = UsuarioPerfil(apellidos="Pérez")
            cliente.roles.append(UsuarioRol(rol=rol_cliente))

            # 2. Admin Taller
            admin_taller = Usuario(
                nombre="Roberto",
                email="roberto.admin@test.com",
                password=hash_password("password123"),
                telefono="77754321",
                ci="9999999",
            )
            admin_taller.perfil = UsuarioPerfil(apellidos="Gómez")
            admin_taller.roles.append(UsuarioRol(rol=rol_admin))

            # 3. Tres Empleados Técnicos
            tecnico1 = Usuario(
                nombre="Luis",
                email="luis.tec@test.com",
                password=hash_password("password123"),
                ci="7771111"
            )
            tecnico1.roles.append(UsuarioRol(rol=rol_tecnico))

            tecnico2 = Usuario(
                nombre="Juan",
                email="juan.tec@test.com",
                password=hash_password("password123"),
                ci="7772222"
            )
            tecnico2.roles.append(UsuarioRol(rol=rol_tecnico))

            tecnico3 = Usuario(
                nombre="Diego",
                email="diego.tec@test.com",
                password=hash_password("password123"),
                ci="7773333"
            )
            tecnico3.roles.append(UsuarioRol(rol=rol_tecnico))

            session.add_all([cliente, admin_taller, tecnico1, tecnico2, tecnico3])
            await session.flush()

            print("[Seed] Creando Vehículo para Cliente...")
            vehiculo = Vehiculo(
                marca="Toyota",
                modelo="Corolla",
                anio=2021,
                placa="4567XYZ",
                usuario_id=cliente.id
            )
            session.add(vehiculo)

            print("[Seed] Creando Perfil Admin...")
            admin_perfil = Admin(usuario_id=admin_taller.id, disponible=True)
            session.add(admin_perfil)
            await session.flush()

            print("[Seed] Creando Talleres y Sucursales en Santa Cruz...")
            taller1 = Taller(
                nombre="Taller Multimarca UAGRM",
                descripcion="Especialistas en auxilio rápido cerca de la universidad.",
                admin_id=admin_perfil.id
            )
            taller2 = Taller(
                nombre="Mecánica Villa 1ro de Mayo",
                descripcion="Taller completo, chapistería y motores.",
                admin_id=admin_perfil.id
            )
            session.add_all([taller1, taller2])
            await session.flush()

            # Coordenadas SCZ
            lat_uagrm, lng_uagrm = -17.7766, -63.1950
            lat_villa, lng_villa = -17.8005, -63.1500
            lat_norte, lng_norte = -17.7650, -63.1800

            suc1 = Sucursal(
                nombre="Sucursal Campus",
                direccion="Zona UAGRM, 3er Anillo Interno",
                latitud=lat_uagrm,
                longitud=lng_uagrm,
                telefono="3334455",
                taller_id=taller1.id,
                ubicacion=WKTElement(f"POINT({lng_uagrm} {lat_uagrm})", srid=4326)
            )

            suc2 = Sucursal(
                nombre="Sucursal Villa Central",
                direccion="Plaza Principal Villa 1ro de Mayo",
                latitud=lat_villa,
                longitud=lng_villa,
                telefono="3337788",
                taller_id=taller2.id,
                ubicacion=WKTElement(f"POINT({lng_villa} {lat_villa})", srid=4326)
            )

            suc3 = Sucursal(
                nombre="Sucursal Norte",
                direccion="2do Anillo, Av. Cristo Redentor",
                latitud=lat_norte,
                longitud=lng_norte,
                telefono="3339900",
                taller_id=taller1.id,
                ubicacion=WKTElement(f"POINT({lng_norte} {lat_norte})", srid=4326)
            )
            session.add_all([suc1, suc2, suc3])
            await session.flush()

            print("[Seed] Creando Catálogo de Servicios...")
            serv1 = Servicio(nombre="Auxilio de Batería")
            serv2 = Servicio(nombre="Cambio de Llanta")
            serv3 = Servicio(nombre="Grúa y carrocería")
            serv4 = Servicio(nombre="Mecánica general")
            session.add_all([serv1, serv2, serv3, serv4])
            await session.flush()

            print("[Seed] Vinculando Servicios a Sucursales...")
            # Sucursal Campus (UAGRM) -> Batería, Llantas (rápidos)
            session.add(SucursalServicio(sucursal_id=suc1.id, servicio_id=serv1.id))
            session.add(SucursalServicio(sucursal_id=suc1.id, servicio_id=serv2.id))
            
            # Sucursal Villa -> Motor, Grúa (pesados)
            session.add(SucursalServicio(sucursal_id=suc2.id, servicio_id=serv3.id))
            session.add(SucursalServicio(sucursal_id=suc2.id, servicio_id=serv4.id))
            
            # Sucursal Norte -> Todo
            session.add(SucursalServicio(sucursal_id=suc3.id, servicio_id=serv1.id))
            session.add(SucursalServicio(sucursal_id=suc3.id, servicio_id=serv2.id))
            session.add(SucursalServicio(sucursal_id=suc3.id, servicio_id=serv3.id))
            session.add(SucursalServicio(sucursal_id=suc3.id, servicio_id=serv4.id))

            print("[Seed] Creando Perfiles de Empleados (Técnicos)...")
            emp1 = Empleado(
                usuario_id=tecnico1.id,
                especialidad="Electricista",
                disponible=True,
                sucursal_id=suc1.id,
                latitud=lat_uagrm + 0.001,
                longitud=lng_uagrm + 0.001
            )
            emp2 = Empleado(
                usuario_id=tecnico2.id,
                especialidad="Mecánico Pesado",
                disponible=True,
                sucursal_id=suc2.id,
                latitud=lat_villa + 0.002,
                longitud=lng_villa - 0.001
            )
            emp3 = Empleado(
                usuario_id=tecnico3.id,
                especialidad="Todoterreno",
                disponible=True,
                sucursal_id=suc3.id,
                latitud=lat_norte - 0.001,
                longitud=lng_norte + 0.002
            )
            session.add_all([emp1, emp2, emp3])

            await session.commit()
            print("========================================")
            print("EXITO: SEMBRADO COMPLETADO CON EXITO!")
            print("========================================")
            print("Datos de prueba (Password: password123):")
            print(" - Cliente: carlos.cliente@test.com")
            print(" - Admin:   roberto.admin@test.com")
            print(" - Técnico 1: luis.tec@test.com")
            print(" - Técnico 2: juan.tec@test.com")
            print(" - Técnico 3: diego.tec@test.com")
            print("========================================")

        except Exception as e:
            await session.rollback()
            print(f"ERROR durante el seeding: {e}")
            import traceback
            traceback.print_exc()
            raise


if __name__ == "__main__":
    asyncio.run(seed_data())
