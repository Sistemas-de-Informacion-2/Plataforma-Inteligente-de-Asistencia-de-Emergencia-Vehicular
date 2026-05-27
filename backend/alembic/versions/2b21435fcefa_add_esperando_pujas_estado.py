"""add_esperando_pujas_estado

Revision ID: 2b21435fcefa
Revises: f49785cb64d9
Create Date: 2026-05-27 00:01:37.948351

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '2b21435fcefa'
down_revision: Union[str, Sequence[str], None] = 'f49785cb64d9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Agrega el valor 'ESPERANDO_PUJAS' al enum estado_solicitud.
    # postgres requiere ALTER TYPE para añadir valores a un enum.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE estado_solicitud ADD VALUE IF NOT EXISTS 'ESPERANDO_PUJAS' AFTER 'PENDIENTE'"
        )


def downgrade() -> None:
    # PostgreSQL no permite eliminar valores individuales de un enum fácilmente.
    pass
