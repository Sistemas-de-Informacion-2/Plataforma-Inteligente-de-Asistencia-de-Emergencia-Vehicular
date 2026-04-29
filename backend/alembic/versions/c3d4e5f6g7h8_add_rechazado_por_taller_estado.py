"""add_rechazado_por_taller_estado

Revision ID: c3d4e5f6g7h8
Revises: b2c3d4e5f6g7
Create Date: 2026-04-22 20:20:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'c3d4e5f6g7h8'
down_revision: Union[str, Sequence[str], None] = 'b2c3d4e5f6g7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    Agrega el valor 'RECHAZADO_POR_TALLER' al enum estado_solicitud.
    
    Fase 3 del modelo 'Uber para Mecánicos Inverso':
    El taller decide no atender la solicitud.
    """
    op.execute(
        "ALTER TYPE estado_solicitud ADD VALUE IF NOT EXISTS 'RECHAZADO_POR_TALLER' AFTER 'ESPERANDO_ACEPTACION_TALLER'"
    )


def downgrade() -> None:
    """
    No es posible eliminar un valor de un enum en PostgreSQL.
    """
    pass
