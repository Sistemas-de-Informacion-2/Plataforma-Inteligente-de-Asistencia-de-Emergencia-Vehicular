# backend/clean_db_fixed.py
"""
Script para limpiar completamente la base de datos.
Versión corregida para asyncpg (no múltiples comandos en una sola llamada).
"""

import asyncio
from sqlalchemy import text
from app.core.database import AsyncSessionLocal


async def clean_database():
    print("⚠️  ADVERTENCIA: Esto ELIMINARÁ TODOS LOS DATOS de la base de datos.")
    print("   ¿Estás seguro? (Escribe 'SI' para confirmar)")
    
    confirm = input("> ")
    if confirm != "SI":
        print("❌ Operación cancelada.")
        return
    
    print("\n⏳ Limpiando base de datos...")
    
    async with AsyncSessionLocal() as session:
        # 1. Tablas con dependencias profundas
        print("   📦 Eliminando pagos...")
        await session.execute(text("DELETE FROM pagos;"))
        
        print("   📦 Eliminando detalles_orden...")
        await session.execute(text("DELETE FROM detalles_orden;"))
        
        print("   📦 Eliminando ordenes_trabajo...")
        await session.execute(text("DELETE FROM ordenes_trabajo;"))
        
        print("   📦 Eliminando asignaciones...")
        await session.execute(text("DELETE FROM asignaciones;"))
        
        print("   📦 Eliminando pujas...")
        await session.execute(text("DELETE FROM pujas;"))
        
        print("   📦 Eliminando diagnosticos_ia...")
        await session.execute(text("DELETE FROM diagnosticos_ia;"))
        
        print("   📦 Eliminando evidencias...")
        await session.execute(text("DELETE FROM evidencias;"))
        
        print("   📦 Eliminando solicitudes_emergencia...")
        await session.execute(text("DELETE FROM solicitudes_emergencia;"))
        
        print("   📦 Eliminando resenas_foro...")
        await session.execute(text("DELETE FROM resenas_foro;"))
        
        print("   📦 Eliminando notificaciones...")
        await session.execute(text("DELETE FROM notificaciones;"))
        
        # 2. Tablas intermedias M:N
        print("   📦 Eliminando sucursal_servicios...")
        await session.execute(text("DELETE FROM sucursal_servicios;"))
        
        print("   📦 Eliminando rol_permisos...")
        await session.execute(text("DELETE FROM rol_permisos;"))
        
        print("   📦 Eliminando usuario_roles...")
        await session.execute(text("DELETE FROM usuario_roles;"))
        
        # 3. Tablas de empleados y admins
        print("   📦 Eliminando empleados...")
        await session.execute(text("DELETE FROM empleados;"))
        
        print("   📦 Eliminando admins...")
        await session.execute(text("DELETE FROM admins;"))
        
        # 4. Sucursales y talleres
        print("   📦 Eliminando sucursales...")
        await session.execute(text("DELETE FROM sucursales;"))
        
        print("   📦 Eliminando talleres...")
        await session.execute(text("DELETE FROM talleres;"))
        
        # 5. Vehículos
        print("   📦 Eliminando vehiculos...")
        await session.execute(text("DELETE FROM vehiculos;"))
        
        # 6. Usuarios y perfiles
        print("   📦 Eliminando usuario_perfiles...")
        await session.execute(text("DELETE FROM usuario_perfiles;"))
        
        print("   📦 Eliminando usuarios...")
        await session.execute(text("DELETE FROM usuarios;"))
        
        # 7. Catálogos
        print("   📦 Eliminando servicios...")
        await session.execute(text("DELETE FROM servicios;"))
        
        print("   📦 Eliminando metodos_pago...")
        await session.execute(text("DELETE FROM metodos_pago;"))
        
        print("   📦 Eliminando permisos...")
        await session.execute(text("DELETE FROM permisos;"))
        
        print("   📦 Eliminando roles...")
        await session.execute(text("DELETE FROM roles;"))
        
        # 8. Reiniciar secuencias (UNA POR UNA)
        print("   🔄 Reiniciando secuencias de IDs...")
        
        # Lista de secuencias a reiniciar
        secuencias = [
            'usuarios', 'talleres', 'sucursales', 'empleados', 
            'admins', 'vehiculos', 'solicitudes_emergencia'
        ]
        
        for seq in secuencias:
            print(f"      Reiniciando secuencia: {seq}")
            await session.execute(
                text(f"SELECT setval(pg_get_serial_sequence('{seq}', 'id'), 1, false);")
            )
        
        await session.commit()
        
    print("\n✅ Base de datos limpiada completamente!")
    print("💡 Ahora puedes ejecutar 'python seed.py' para cargar datos iniciales.")


async def clean_and_reset():
    await clean_database()


if __name__ == "__main__":
    asyncio.run(clean_and_reset())