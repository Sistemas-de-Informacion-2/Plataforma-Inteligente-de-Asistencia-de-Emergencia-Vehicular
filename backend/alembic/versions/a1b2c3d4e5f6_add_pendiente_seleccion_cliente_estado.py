"""add_pendiente_seleccion_cliente_estado

Revision ID: a1b2c3d4e5f6
Revises: 55e3569ea840
Create Date: 2026-04-22 19:30:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = '55e3569ea840'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    Agrega el valor 'PENDIENTE_SELECCION_CLIENTE' al enum estado_solicitud.

    Fase 1 del modelo 'Uber para Mecánicos Inverso':
    El cliente recibe recomendaciones de talleres y elige.
    Este estado indica que la solicitud está esperando la selección del cliente.

    NOTA: ALTER TYPE ... ADD VALUE no puede ejecutarse dentro de una
    transacción en PostgreSQL < 12. En PG 12+ funciona dentro de una tx.
    IF NOT EXISTS previene errores si se ejecuta múltiples veces.
    """
    op.execute(
        "ALTER TYPE estado_solicitud ADD VALUE IF NOT EXISTS 'PENDIENTE_SELECCION_CLIENTE' AFTER 'PENDIENTE'"
    )


def downgrade() -> None:
    """
    No es posible eliminar un valor de un enum en PostgreSQL.
    El valor permanecerá pero no será utilizado si se hace downgrade.
    """
    pass
