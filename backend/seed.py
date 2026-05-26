# backend/seed.py
"""
Script de inicialización y carga de datos iniciales (Seeder) para la base de datos.
Crea los roles del sistema, permisos, servicios base y usuarios de prueba.
"""

import asyncio
from sqlalchemy import select
from app.core.database import AsyncSessionLocal, engine
from app.core.security import hash_password
from app.models.rol import Rol, UsuarioRol
from app.models.usuario import Usuario, UsuarioPerfil
from app.models.servicio import Servicio


async def seed_database():
    print("⏳ Iniciando la carga de datos de prueba (seeder)...")
    async with AsyncSessionLocal() as session:
        # 1. ── CARGAR ROLES DEL SISTEMA ────────────────────────────────
        roles_sistema = [
            "SUPER_ADMIN",
            "ADMIN_TALLER",
            "MECANICO",
            "CLIENTE",
        ]
        roles_db = {}

        print("\n   Creando roles del sistema...")
        for r_name in roles_sistema:
            stmt = select(Rol).where(Rol.nombre == r_name)
            result = await session.execute(stmt)
            rol = result.scalar_one_or_none()

            if not rol:
                rol = Rol(nombre=r_name)
                session.add(rol)
                await session.flush()
                print(f"   ✅ Rol creado: '{r_name}'")
            else:
                print(f"   ℹ️ El rol '{r_name}' ya existe.")
            roles_db[r_name] = rol

        # B. Super Admin de Prueba (admin@gmail.com)
        stmt_admin = select(Usuario).where(Usuario.email == "admin@gmail.com")
        result_admin = await session.execute(stmt_admin)
        admin = result_admin.scalar_one_or_none()

        if not admin:
            admin = Usuario(
                nombre="Super Administrador",
                email="admin@gmail.com",
                password=hash_password("admin123"),
                telefono="77112233",
                ci="7654321",
            )
            session.add(admin)
            await session.flush()

            # Rol Super Admin
            admin_rol = UsuarioRol(
                usuario_id=admin.id, rol_id=roles_db["SUPER_ADMIN"].id
            )
            session.add(admin_rol)
            print(
                "   ✅ Usuario SUPER_ADMIN de prueba creado: admin@gmail.com (clave: admin123)"
            )
        else:
            print("   ℹ️ El usuario admin@gmail.com ya existe.")

        await session.commit()
        print("\n🎉 Carga de datos completada exitosamente!")


if __name__ == "__main__":
    asyncio.run(seed_database())
