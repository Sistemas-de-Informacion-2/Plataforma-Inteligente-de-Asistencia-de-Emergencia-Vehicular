"""Add KPI timestamps and sos_notificaciones_sucursal table

Revision ID: d7e8f9a0b1c2
Revises: af4b88c9ec6a
Create Date: 2026-06-02 00:00:00.000000

Cambios incluidos:
  - asignaciones: fecha_aceptacion, fecha_llegada
  - solicitudes_emergencia: fecha_finalizacion
  - pujas: fecha_aceptacion
  - diagnosticos_ia: categoria_incidencia (+ index)
  - Nueva tabla: sos_notificaciones_sucursal
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'd7e8f9a0b1c2'
down_revision: Union[str, Sequence[str], None] = 'af4b88c9ec6a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── asignaciones ──────────────────────────────────────────────
    op.add_column('asignaciones',
        sa.Column('fecha_aceptacion', sa.DateTime(timezone=True), nullable=True))
    op.add_column('asignaciones',
        sa.Column('fecha_llegada', sa.DateTime(timezone=True), nullable=True))

    # ── solicitudes_emergencia ────────────────────────────────────
    op.add_column('solicitudes_emergencia',
        sa.Column('fecha_finalizacion', sa.DateTime(timezone=True), nullable=True))

    # ── pujas ─────────────────────────────────────────────────────
    op.add_column('pujas',
        sa.Column('fecha_aceptacion', sa.DateTime(timezone=True), nullable=True))

    # ── diagnosticos_ia ───────────────────────────────────────────
    op.add_column('diagnosticos_ia',
        sa.Column('categoria_incidencia', sa.String(100), nullable=True))
    op.create_index(
        'ix_diagnosticos_ia_categoria_incidencia',
        'diagnosticos_ia',
        ['categoria_incidencia'],
    )

    # ── sos_notificaciones_sucursal (nueva tabla) ─────────────────
    op.create_table(
        'sos_notificaciones_sucursal',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('solicitud_id', sa.Integer(), nullable=False),
        sa.Column('sucursal_id', sa.Integer(), nullable=False),
        sa.Column('fecha_envio', sa.DateTime(timezone=True), nullable=True),
        sa.Column('respondio', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.ForeignKeyConstraint(
            ['solicitud_id'], ['solicitudes_emergencia.id'],
            ondelete='CASCADE',
        ),
        sa.ForeignKeyConstraint(
            ['sucursal_id'], ['sucursales.id'],
            ondelete='CASCADE',
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'solicitud_id', 'sucursal_id',
            name='uq_sos_notif_solicitud_sucursal',
        ),
    )
    op.create_index(
        op.f('ix_sos_notificaciones_sucursal_id'),
        'sos_notificaciones_sucursal',
        ['id'],
    )
    op.create_index(
        'ix_sos_notif_solicitud_id',
        'sos_notificaciones_sucursal',
        ['solicitud_id'],
    )
    op.create_index(
        'ix_sos_notif_sucursal_id',
        'sos_notificaciones_sucursal',
        ['sucursal_id'],
    )


def downgrade() -> None:
    # ── sos_notificaciones_sucursal ───────────────────────────────
    op.drop_index('ix_sos_notif_sucursal_id', table_name='sos_notificaciones_sucursal')
    op.drop_index('ix_sos_notif_solicitud_id', table_name='sos_notificaciones_sucursal')
    op.drop_index(
        op.f('ix_sos_notificaciones_sucursal_id'),
        table_name='sos_notificaciones_sucursal',
    )
    op.drop_table('sos_notificaciones_sucursal')

    # ── diagnosticos_ia ───────────────────────────────────────────
    op.drop_index('ix_diagnosticos_ia_categoria_incidencia', table_name='diagnosticos_ia')
    op.drop_column('diagnosticos_ia', 'categoria_incidencia')

    # ── pujas ─────────────────────────────────────────────────────
    op.drop_column('pujas', 'fecha_aceptacion')

    # ── solicitudes_emergencia ────────────────────────────────────
    op.drop_column('solicitudes_emergencia', 'fecha_finalizacion')

    # ── asignaciones ──────────────────────────────────────────────
    op.drop_column('asignaciones', 'fecha_llegada')
    op.drop_column('asignaciones', 'fecha_aceptacion')
