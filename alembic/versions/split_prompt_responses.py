"""Split prompt_responses into sits and checkins

Revision ID: split_prompt_responses
Revises: add_duration_seconds
Create Date: 2026-02-23

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'split_prompt_responses'
down_revision: Union[str, Sequence[str], None] = 'add_duration_seconds'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create sits table
    op.create_table(
        'sits',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('duration_seconds', sa.Float(), nullable=False),
        sa.Column('started_at', sa.DateTime(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_sits_user_id', 'sits', ['user_id'])

    # Create checkins table
    op.create_table(
        'checkins',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('flow_id', sa.Uuid(), nullable=True),
        sa.Column('responded_at', sa.DateTime(), nullable=False),
        sa.Column('steps', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('voice_note_s3_url', sa.String(), nullable=True),
        sa.Column('voice_note_duration_seconds', sa.Float(), nullable=True),
        sa.Column('transcription', sa.Text(), nullable=True),
        sa.Column('transcription_status', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['flow_id'], ['flows.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_checkins_user_id', 'checkins', ['user_id'])

    conn = op.get_bind()

    # Migrate timer rows (duration_seconds IS NOT NULL) -> sits
    # started_at = responded_at - duration_seconds
    conn.execute(sa.text("""
        INSERT INTO sits (id, user_id, duration_seconds, started_at, created_at)
        SELECT
            id,
            user_id,
            duration_seconds,
            responded_at - (duration_seconds || ' seconds')::interval AS started_at,
            created_at
        FROM prompt_responses
        WHERE duration_seconds IS NOT NULL
          AND user_id IS NOT NULL
    """))

    # Migrate check-in rows (flow_id IS NOT NULL or duration_seconds IS NULL) -> checkins
    conn.execute(sa.text("""
        INSERT INTO checkins (id, user_id, flow_id, responded_at, steps, voice_note_s3_url,
                              voice_note_duration_seconds, transcription, transcription_status, created_at)
        SELECT
            id,
            user_id,
            flow_id,
            responded_at,
            steps,
            voice_note_s3_url,
            voice_note_duration_seconds,
            transcription,
            transcription_status,
            created_at
        FROM prompt_responses
        WHERE duration_seconds IS NULL
          AND user_id IS NOT NULL
    """))

    # Drop the old table
    op.drop_index('ix_prompt_responses_user_id', table_name='prompt_responses')
    op.drop_constraint('fk_prompt_responses_flow_id', 'prompt_responses', type_='foreignkey')
    op.drop_constraint('fk_prompt_responses_user_id', 'prompt_responses', type_='foreignkey')
    op.drop_table('prompt_responses')


def downgrade() -> None:
    # Recreate prompt_responses
    op.create_table(
        'prompt_responses',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=True),
        sa.Column('flow_id', sa.Uuid(), nullable=True),
        sa.Column('responded_at', sa.DateTime(), nullable=False),
        sa.Column('steps', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('voice_note_s3_url', sa.String(), nullable=True),
        sa.Column('voice_note_duration_seconds', sa.Float(), nullable=True),
        sa.Column('transcription', sa.Text(), nullable=True),
        sa.Column('transcription_status', sa.String(), nullable=True),
        sa.Column('duration_seconds', sa.Float(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE', name='fk_prompt_responses_user_id'),
        sa.ForeignKeyConstraint(['flow_id'], ['flows.id'], ondelete='SET NULL', name='fk_prompt_responses_flow_id'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_prompt_responses_user_id', 'prompt_responses', ['user_id'])

    conn = op.get_bind()

    # Restore sits -> prompt_responses
    conn.execute(sa.text("""
        INSERT INTO prompt_responses (id, user_id, flow_id, responded_at, steps, voice_note_s3_url,
                                     voice_note_duration_seconds, transcription, transcription_status,
                                     duration_seconds, created_at)
        SELECT
            id,
            user_id,
            NULL AS flow_id,
            started_at + (duration_seconds || ' seconds')::interval AS responded_at,
            NULL AS steps,
            NULL AS voice_note_s3_url,
            NULL AS voice_note_duration_seconds,
            NULL AS transcription,
            NULL AS transcription_status,
            duration_seconds,
            created_at
        FROM sits
    """))

    # Restore checkins -> prompt_responses
    conn.execute(sa.text("""
        INSERT INTO prompt_responses (id, user_id, flow_id, responded_at, steps, voice_note_s3_url,
                                     voice_note_duration_seconds, transcription, transcription_status,
                                     duration_seconds, created_at)
        SELECT
            id,
            user_id,
            flow_id,
            responded_at,
            steps,
            voice_note_s3_url,
            voice_note_duration_seconds,
            transcription,
            transcription_status,
            NULL AS duration_seconds,
            created_at
        FROM checkins
    """))

    op.drop_index('ix_checkins_user_id', table_name='checkins')
    op.drop_table('checkins')
    op.drop_index('ix_sits_user_id', table_name='sits')
    op.drop_table('sits')
