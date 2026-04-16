# backend/app/core/database.py
"""
Configuración de la base de datos con SQLAlchemy Async.
PostGIS en Docker (puerto 5433).
"""
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from app.core.config import get_settings

settings = get_settings()

# ── Engine async ───────────────────────────────────────────────
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,        # Loguea SQL en modo debug
    future=True,
    pool_size=10,
    max_overflow=20,
)

# ── Fábrica de sesiones async ──────────────────────────────────
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


# ── Clase base para todos los modelos ─────────────────────────
class Base(DeclarativeBase):
    """Base declarativa de la que heredan todos los modelos ORM."""
    pass


# ── Dependencia FastAPI: inyección de sesión async ────────────
async def get_db() -> AsyncSession:
    """
    Generador de sesiones para inyección de dependencias.
    Uso en endpoints:
        async def mi_endpoint(db: AsyncSession = Depends(get_db)):
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()