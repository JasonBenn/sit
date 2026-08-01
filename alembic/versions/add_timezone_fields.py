"""Add timezone fields and convert timestamps to TIMESTAMPTZ

Revision ID: add_timezone_fields
Revises: split_prompt_responses
Create Date: 2026-03-25

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'add_timezone_fields'
down_revision: Union[str, Sequence[str], None] = 'add_schedule_type_device_tokens'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()

    # Convert all datetime columns from TIMESTAMP to TIMESTAMPTZ
    # The USING clause tells Postgres the existing naive values are UTC
    for table, column in [
        ('sits', 'started_at'),
        ('sits', 'created_at'),
        ('checkins', 'responded_at'),
        ('checkins', 'created_at'),
        ('users', 'created_at'),
        ('flows', 'created_at'),
        ('device_tokens', 'created_at'),
        ('chat_messages', 'created_at'),
    ]:
        conn.execute(sa.text(
            f"ALTER TABLE {table} ALTER COLUMN {column} TYPE TIMESTAMPTZ "
            f"USING {column} AT TIME ZONE 'UTC'"
        ))

    # Add timezone column to sits and checkins
    op.add_column('sits', sa.Column('timezone', sa.String(), nullable=True))
    op.add_column('checkins', sa.Column('timezone', sa.String(), nullable=True))

    # Backfill existing rows with America/Los_Angeles
    conn.execute(sa.text("UPDATE sits SET timezone = 'America/Los_Angeles'"))
    conn.execute(sa.text("UPDATE checkins SET timezone = 'America/Los_Angeles'"))


def downgrade() -> None:
    conn = op.get_bind()

    op.drop_column('checkins', 'timezone')
    op.drop_column('sits', 'timezone')

    for table, column in [
        ('sits', 'started_at'),
        ('sits', 'created_at'),
        ('checkins', 'responded_at'),
        ('checkins', 'created_at'),
        ('users', 'created_at'),
        ('flows', 'created_at'),
        ('device_tokens', 'created_at'),
        ('chat_messages', 'created_at'),
    ]:
        conn.execute(sa.text(
            f"ALTER TABLE {table} ALTER COLUMN {column} TYPE TIMESTAMP "
            f"USING {column} AT TIME ZONE 'UTC'"
        ))
