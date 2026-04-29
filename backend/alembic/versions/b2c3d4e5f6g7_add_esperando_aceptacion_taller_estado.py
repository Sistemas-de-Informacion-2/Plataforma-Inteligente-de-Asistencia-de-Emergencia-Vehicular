"""add_esperando_aceptacion_taller_estado

Revision ID: b2c3d4e5f6g7
Revises: a1b2c3d4e5f6
Create Date: 2026-04-22 20:05:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6g7'
down_revision: Union[str, Sequence[str], None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    Agrega el valor 'ESPERANDO_ACEPTACION_TALLER' al enum estado_solicitud.
    
    Fase 2 del modelo 'Uber para Mecánicos Inverso':
    El cliente ya eligió sucursal, ahora el taller debe aceptar.
    """
    op.execute(
        "ALTER TYPE estado_solicitud ADD VALUE IF NOT EXISTS 'ESPERANDO_ACEPTACION_TALLER' AFTER 'PENDIENTE_SELECCION_CLIENTE'"
    )


def downgrade() -> None:
    """
    No es posible eliminar un valor de un enum en PostgreSQL.
    """
    pass
