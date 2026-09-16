"""Listens: guided recordings the user played, so search can skip them

Revision ID: add_listens
Revises: add_practice_library
Create Date: 2026-09-15

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'add_listens'
down_revision: Union[str, Sequence[str], None] = 'add_practice_library'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'listens',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        # Nullable: a track keeps playing after the user switches sessions.
        sa.Column('session_id', postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('morning_sessions.id'), nullable=True),
        sa.Column('recording_id', sa.String(), nullable=False),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_listens_session_id', 'listens', ['session_id'])
    op.create_index('ix_listens_recording_id', 'listens', ['recording_id'])


def downgrade() -> None:
    op.drop_index('ix_listens_recording_id', table_name='listens')
    op.drop_index('ix_listens_session_id', table_name='listens')
    op.drop_table('listens')
