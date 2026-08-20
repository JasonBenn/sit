"""Sits: distinguish exact start times from nominal backfill times

Revision ID: add_sit_time_known
Revises: add_morning_sessions
Create Date: 2026-08-20

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'add_sit_time_known'
down_revision: Union[str, Sequence[str], None] = 'add_morning_sessions'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('sits', sa.Column('time_known', sa.Boolean(), nullable=False,
                                    server_default=sa.true()))
    # Backfilled rows are the ones the calendar toggle stamped at a nominal
    # 8:00:00 local; every organically-logged sit has a real clock time.
    op.execute("""
        UPDATE sits SET time_known = false
        WHERE to_char(started_at AT TIME ZONE COALESCE(timezone, 'America/Los_Angeles'),
                      'HH24:MI:SS') = '08:00:00'
    """)


def downgrade() -> None:
    op.drop_column('sits', 'time_known')
