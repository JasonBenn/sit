"""Add users, flows, chat_messages tables and update prompt_responses

Revision ID: add_users_flows_chat
Revises: drop_unused_tables
Create Date: 2026-02-14

"""
from typing import Sequence, Union
import json
import uuid
from datetime import datetime

from alembic import op
import sqlalchemy as sa
import sqlmodel
import bcrypt
from sqlalchemy.dialects import postgresql

revision: str = 'add_users_flows_chat'
down_revision: Union[str, Sequence[str], None] = 'drop_unused_tables'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create users table
    op.create_table('users',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('username', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('password_hash', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('current_flow_id', sa.Uuid(), nullable=True),
        sa.Column('notification_count', sa.Integer(), nullable=False, server_default='3'),
        sa.Column('notification_start_hour', sa.Integer(), nullable=False, server_default='9'),
        sa.Column('notification_end_hour', sa.Integer(), nullable=False, server_default='22'),
        sa.Column('conversation_starters', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('has_seen_onboarding', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_users_username', 'users', ['username'], unique=True)

    # Create flows table
    op.create_table('flows',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('name', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('description', sqlmodel.sql.sqltypes.AutoString(), nullable=False, server_default=''),
        sa.Column('steps_json', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('source_username', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('source_flow_name', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('visibility', sqlmodel.sql.sqltypes.AutoString(), nullable=False, server_default='private'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_flows_user_id', 'flows', ['user_id'])

    # Add FK from users.current_flow_id -> flows.id (after flows table exists)
    op.create_foreign_key('fk_users_current_flow_id', 'users', 'flows', ['current_flow_id'], ['id'], ondelete='SET NULL')

    # Create chat_messages table
    op.create_table('chat_messages',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('role', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_chat_messages_user_id', 'chat_messages', ['user_id'])

    # Add new columns to prompt_responses
    op.add_column('prompt_responses', sa.Column('user_id', sa.Uuid(), nullable=True))
    op.add_column('prompt_responses', sa.Column('flow_id', sa.Uuid(), nullable=True))
    op.add_column('prompt_responses', sa.Column('steps', postgresql.JSONB(astext_type=sa.Text()), nullable=True))
    op.create_foreign_key('fk_prompt_responses_user_id', 'prompt_responses', 'users', ['user_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key('fk_prompt_responses_flow_id', 'prompt_responses', 'flows', ['flow_id'], ['id'], ondelete='SET NULL')
    op.create_index('ix_prompt_responses_user_id', 'prompt_responses', ['user_id'])

    # Make legacy columns nullable (temporarily, for backfill)
    op.alter_column('prompt_responses', 'initial_answer', existing_type=sqlmodel.sql.sqltypes.AutoString(), nullable=True)
    op.alter_column('prompt_responses', 'final_state', existing_type=sqlmodel.sql.sqltypes.AutoString(), nullable=True)

    # --- Data migration: create user, flow, backfill responses ---

    conn = op.get_bind()

    user_id = uuid.uuid4()
    flow_id = uuid.uuid4()
    now = datetime.utcnow()

    password_hash = bcrypt.hashpw(b"Lovelife1!", bcrypt.gensalt()).decode()

    from app.default_flow import DEFAULT_FLOW_NAME, DEFAULT_FLOW_DESCRIPTION, DEFAULT_FLOW_STEPS

    # Create user
    conn.execute(
        sa.text("""
            INSERT INTO users (id, username, password_hash, current_flow_id, notification_count,
                               notification_start_hour, notification_end_hour, has_seen_onboarding, created_at)
            VALUES (:id, :username, :password_hash, NULL, 3, 9, 22, true, :created_at)
        """),
        {"id": user_id, "username": "jasoncbenn", "password_hash": password_hash, "created_at": now},
    )

    # Create default flow
    conn.execute(
        sa.text("""
            INSERT INTO flows (id, user_id, name, description, steps_json, visibility, created_at)
            VALUES (:id, :user_id, :name, :description, :steps_json, 'private', :created_at)
        """),
        {
            "id": flow_id, "user_id": user_id, "name": DEFAULT_FLOW_NAME,
            "description": DEFAULT_FLOW_DESCRIPTION,
            "steps_json": json.dumps(DEFAULT_FLOW_STEPS), "created_at": now,
        },
    )

    # Set user's current flow
    conn.execute(
        sa.text("UPDATE users SET current_flow_id = :flow_id WHERE id = :user_id"),
        {"flow_id": flow_id, "user_id": user_id},
    )

    # Backfill prompt_responses: map old columns → steps JSON
    # (in_view, None, reflection_complete)           → [[1,0],[2,0]]
    # (not_in_view, worked, reflection_complete)      → [[1,1],[3,0],[2,0]]
    # (not_in_view, didnt_work, voice_note_recorded)  → [[1,1],[3,1],[4,0]]
    step_mappings = {
        ("in_view", None, "reflection_complete"): [[1, 0], [2, 0]],
        ("not_in_view", "worked", "reflection_complete"): [[1, 1], [3, 0], [2, 0]],
        ("not_in_view", "didnt_work", "voice_note_recorded"): [[1, 1], [3, 1], [4, 0]],
    }

    for (initial, gate, final), steps in step_mappings.items():
        if gate is None:
            conn.execute(
                sa.text("""
                    UPDATE prompt_responses
                    SET user_id = :user_id, flow_id = :flow_id, steps = :steps
                    WHERE initial_answer = :initial AND gate_exercise_result IS NULL AND final_state = :final
                """),
                {"user_id": user_id, "flow_id": flow_id, "steps": json.dumps(steps),
                 "initial": initial, "final": final},
            )
        else:
            conn.execute(
                sa.text("""
                    UPDATE prompt_responses
                    SET user_id = :user_id, flow_id = :flow_id, steps = :steps
                    WHERE initial_answer = :initial AND gate_exercise_result = :gate AND final_state = :final
                """),
                {"user_id": user_id, "flow_id": flow_id, "steps": json.dumps(steps),
                 "initial": initial, "gate": gate, "final": final},
            )

    # Drop legacy columns
    op.drop_column('prompt_responses', 'initial_answer')
    op.drop_column('prompt_responses', 'gate_exercise_result')
    op.drop_column('prompt_responses', 'final_state')


def downgrade() -> None:
    # Re-add legacy columns
    op.add_column('prompt_responses', sa.Column('initial_answer', sqlmodel.sql.sqltypes.AutoString(), nullable=True))
    op.add_column('prompt_responses', sa.Column('gate_exercise_result', sqlmodel.sql.sqltypes.AutoString(), nullable=True))
    op.add_column('prompt_responses', sa.Column('final_state', sqlmodel.sql.sqltypes.AutoString(), nullable=True))

    # Drop new columns from prompt_responses
    op.drop_index('ix_prompt_responses_user_id', table_name='prompt_responses')
    op.drop_constraint('fk_prompt_responses_flow_id', 'prompt_responses', type_='foreignkey')
    op.drop_constraint('fk_prompt_responses_user_id', 'prompt_responses', type_='foreignkey')
    op.drop_column('prompt_responses', 'steps')
    op.drop_column('prompt_responses', 'flow_id')
    op.drop_column('prompt_responses', 'user_id')

    # Drop new tables
    op.drop_index('ix_chat_messages_user_id', table_name='chat_messages')
    op.drop_table('chat_messages')
    op.drop_constraint('fk_users_current_flow_id', 'users', type_='foreignkey')
    op.drop_index('ix_flows_user_id', table_name='flows')
    op.drop_table('flows')
    op.drop_index('ix_users_username', table_name='users')
    op.drop_table('users')
