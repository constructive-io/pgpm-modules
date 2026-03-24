-- Deploy schemas/status_public/tables/user_achievements/table to pg

-- requires: schemas/status_public/schema

BEGIN;

CREATE TABLE status_public.user_achievements (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    user_id uuid NOT NULL,
    name text NOT NULL, -- relates to level_requirements.name
    count int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    constraint user_achievements_unique_key unique (user_id, name)
);

COMMENT ON TABLE status_public.user_achievements IS 'This table represents the users progress for particular level requirements, tallying the total count. This table is updated via triggers and should not be updated maually.';
COMMENT ON COLUMN status_public.user_achievements.id IS 'Unique identifier for this achievement progress record';
COMMENT ON COLUMN status_public.user_achievements.user_id IS 'User whose progress is being tracked';
COMMENT ON COLUMN status_public.user_achievements.name IS 'Name of the level requirement this progress relates to';
COMMENT ON COLUMN status_public.user_achievements.count IS 'Accumulated count toward the requirement (updated by triggers)';
COMMENT ON COLUMN status_public.user_achievements.created_at IS 'Timestamp when this progress record was first created';

CREATE INDEX ON status_public.user_achievements (user_id, name);

COMMIT;
