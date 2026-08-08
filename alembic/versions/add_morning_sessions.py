"""Add morning_sessions and morning_messages

Revision ID: add_morning_sessions
Revises: add_timezone_fields
Create Date: 2026-08-07

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'add_morning_sessions'
down_revision: Union[str, Sequence[str], None] = 'add_timezone_fields'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'morning_sessions',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('journal_heading', sa.Text(), nullable=True),
        sa.Column('journal_written_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('sit_id', sa.Uuid(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['sit_id'], ['sits.id']),
    )
    op.create_table(
        'morning_messages',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('session_id', sa.Uuid(), nullable=False),
        sa.Column('role', sa.String(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('tool_label', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['session_id'], ['morning_sessions.id']),
    )
    op.create_index('ix_morning_messages_session_id', 'morning_messages', ['session_id'])


def downgrade() -> None:
    op.drop_table('morning_messages')
    op.drop_table('morning_sessions')
