# backend/alembic/env.py
"""
Configuración de Alembic para migraciones async con PostGIS.
Lee la URL de la base de datos desde nuestro Settings (Pydantic).
Filtra tablas internas de PostGIS/Tiger/Topology para autogenerate limpio.
"""

import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

# ── Configuración de Alembic ──────────────────────────────────
config = context.config

# Logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# ── Inyectar la URL desde nuestro .env ────────────────────────
from app.core.config import get_settings  # noqa: E402

settings = get_settings()
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# ── Importar TODOS los modelos para autogenerate ──────────────
from app.models import Base  # noqa: E402

target_metadata = Base.metadata

# ── Solo seguir las tablas definidas por nuestros modelos ─────
OUR_TABLES = set(target_metadata.tables.keys())


def include_object(object, name, type_, reflected, compare_to):
    """
    Solo incluir objetos que pertenezcan a NUESTROS modelos.
    Ignora todo lo reflejado (tablas internas PostGIS, tiger, topology, etc.)
    """
    if type_ == "table":
        # Si la tabla fue reflejada (existe en BD pero no en nuestros modelos),
        # la ignoramos completamente
        if reflected and name not in OUR_TABLES:
            return False
        return True

    # Para columnas, índices, etc., incluir solo si pertenecen a nuestras tablas
    if hasattr(object, "table") and object.table is not None:
        table_name = object.table.name
        if table_name not in OUR_TABLES:
            return False

    return True


# ── Migración offline (genera SQL sin conectar) ──────────────
def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_object=include_object,
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        include_object=include_object,
        compare_type=True,
    )

    with context.begin_transaction():
        context.run_migrations()


# ── Migración online (conecta a la BD real) ──────────────────
async def run_async_migrations() -> None:
    """Crea un engine async y ejecuta las migraciones."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
