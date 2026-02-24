"""Add duration_seconds to prompt_responses

Revision ID: add_duration_seconds
Revises: add_users_flows_chat
Create Date: 2026-02-23

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'add_duration_seconds'
down_revision: Union[str, Sequence[str], None] = 'add_users_flows_chat'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('prompt_responses', sa.Column('duration_seconds', sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column('prompt_responses', 'duration_seconds')
