"""Components carry their source, shown wherever the practice is offered

Revision ID: add_component_citation
Revises: add_listens
Create Date: 2026-09-17

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'add_component_citation'
down_revision: Union[str, Sequence[str], None] = 'add_listens'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Nullable: a practice with no traceable source shows no citation rather
    # than a made-up one. ensure_seeds backfills the seeded ones on startup.
    op.add_column('components', sa.Column('citation', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('components', 'citation')
