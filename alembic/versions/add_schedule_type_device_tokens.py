"""Add schedule_type to checkins and device_tokens table

Revision ID: add_schedule_type_device_tokens
Revises: split_prompt_responses
Create Date: 2026-03-04

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'add_schedule_type_device_tokens'
down_revision: Union[str, Sequence[str], None] = 'split_prompt_responses'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()

    # Add schedule_type to checkins (idempotent)
    # Values: 'random' (scheduled local notification), 'webhook' (triggered by external event), null (manual/legacy)
    result = conn.execute(sa.text(
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_name='checkins' AND column_name='schedule_type'"
    ))
    if not result.fetchone():
        op.add_column('checkins', sa.Column('schedule_type', sa.String(), nullable=True))

    # Create device_tokens table (idempotent — may already exist from manual setup)
    result = conn.execute(sa.text(
        "SELECT 1 FROM information_schema.tables WHERE table_name='device_tokens'"
    ))
    if not result.fetchone():
        op.create_table(
            'device_tokens',
            sa.Column('id', sa.Uuid(), nullable=False),
            sa.Column('user_id', sa.Uuid(), nullable=False),
            sa.Column('token', sa.String(), nullable=False),
            sa.Column('platform', sa.String(), nullable=False),  # 'watchos'
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('token'),
        )

    # Add index if missing
    result = conn.execute(sa.text(
        "SELECT 1 FROM pg_indexes WHERE tablename='device_tokens' AND indexname='ix_device_tokens_user_id'"
    ))
    if not result.fetchone():
        op.create_index('ix_device_tokens_user_id', 'device_tokens', ['user_id'])


def downgrade() -> None:
    op.drop_index('ix_device_tokens_user_id', table_name='device_tokens')
    op.drop_table('device_tokens')
    op.drop_column('checkins', 'schedule_type')
