"""Practice library: components, and the program each sit/marker carries

Revision ID: add_practice_library
Revises: add_sit_time_known
Create Date: 2026-09-15

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'add_practice_library'
down_revision: Union[str, Sequence[str], None] = 'add_sit_time_known'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'components',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('slug', sa.String(), nullable=False, unique=True),
        sa.Column('kind', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('summary', sa.Text(), nullable=False),
        sa.Column('steps_json', postgresql.JSONB(), nullable=False),
        sa.Column('source', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_components_slug', 'components', ['slug'])
    # Nullable on both: sits logged before the library have no program, and most
    # messages never need a payload.
    op.add_column('sits', sa.Column('program_json', postgresql.JSONB(), nullable=True))
    op.add_column('morning_messages', sa.Column('data', postgresql.JSONB(), nullable=True))


def downgrade() -> None:
    op.drop_column('morning_messages', 'data')
    op.drop_column('sits', 'program_json')
    op.drop_index('ix_components_slug', table_name='components')
    op.drop_table('components')
