# backend/reset_db_fixed.py
"""
Reseteo completo de la base de datos: DROP + CREATE todas las tablas.
Versión corregida para asyncpg.
"""

import asyncio
from sqlalchemy import text
from alembic import command
from alembic.config import Config
from app.core.database import engine


async def reset_database():
    print("⚠️  ADVERTENCIA: Esto DESTRUIRÁ y RECREARÁ toda la base de datos.")
    print("   ¿Estás seguro? (Escribe 'SI' para confirmar)")
    
    confirm = input("> ")
    if confirm != "SI":
        print("❌ Operación cancelada.")
        return
    
    print("\n⏳ Eliminando todas las tablas...")
    
    async with engine.begin() as conn:
        # Obtener todas las tablas
        result = await conn.execute(text("""
            SELECT tablename FROM pg_tables 
            WHERE schemaname = 'public'
        """))
        tables = result.fetchall()
        
        # Eliminar cada tabla individualmente
        for table in tables:
            table_name = table[0]
            print(f"   🗑️  Eliminando tabla: {table_name}")
            await conn.execute(text(f'DROP TABLE IF EXISTS "{table_name}" CASCADE;'))
    
    print("\n✅ Tablas eliminadas.")
    print("⏳ Recreando tablas con Alembic...")
    
    # Ejecutar migraciones
    alembic_cfg = Config("alembic.ini")
    command.upgrade(alembic_cfg, "head")
    
    print("\n🎉 Base de datos reseteada completamente!")
    print("💡 Ejecuta 'python seed.py' para cargar datos iniciales.")


if __name__ == "__main__":
    asyncio.run(reset_database())