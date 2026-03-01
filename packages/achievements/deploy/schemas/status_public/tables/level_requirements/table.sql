-- Deploy schemas/status_public/tables/level_requirements/table to pg

-- requires: schemas/status_public/schema
-- requires: schemas/status_public/tables/levels/table 

BEGIN;

CREATE TABLE status_public.level_requirements (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
  name text NOT NULL,
  level text NOT NULL,
  required_count int DEFAULT 1,
  priority int DEFAULT 100,
  unique(name, level)
);

COMMENT ON TABLE status_public.level_requirements IS 'Requirements to achieve a level';
COMMENT ON COLUMN status_public.level_requirements.id IS 'Unique identifier for this requirement';
COMMENT ON COLUMN status_public.level_requirements.name IS 'Requirement name (e.g. posts_created, logins); matches user_steps.name';
COMMENT ON COLUMN status_public.level_requirements.level IS 'Level this requirement belongs to (references levels.name)';
COMMENT ON COLUMN status_public.level_requirements.required_count IS 'Number of steps needed to satisfy this requirement (default 1)';
COMMENT ON COLUMN status_public.level_requirements.priority IS 'Display/evaluation order; lower numbers are checked first (default 100)';

CREATE INDEX ON status_public.level_requirements (name, level, priority);
GRANT SELECT ON TABLE status_public.levels TO authenticated;

COMMIT;
