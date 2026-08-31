-- Deploy schemas/app_jobs/tables/scheduled_jobs/table to pg
-- requires: schemas/app_jobs/schema

BEGIN;
CREATE TABLE app_jobs.scheduled_jobs (
  id bigserial PRIMARY KEY,
  database_id uuid NOT NULL,
  actor_id uuid,
  principal_id uuid,
  entity_id uuid,
  organization_id uuid,
  entity_type text,
  queue_name text DEFAULT NULL,
  task_identifier text NOT NULL,
  payload json DEFAULT '{}' ::json NOT NULL,
  priority integer DEFAULT 0 NOT NULL,
  max_attempts integer DEFAULT 25 NOT NULL,
  key text,
  locked_at timestamptz,
  locked_by text,
  schedule_info json NOT NULL,
  last_scheduled timestamptz,
  last_scheduled_id bigint,
  CHECK (length(key) < 513),
  CHECK (length(task_identifier) < 127),
  CHECK (max_attempts >= 1),
  CHECK (length(queue_name) < 127),
  CHECK (length(locked_by) > 3),
  UNIQUE (key)
);

COMMENT ON TABLE app_jobs.scheduled_jobs IS 'Recurring/cron-style job definitions: each row spawns jobs on a schedule, optionally scoped to a database';
COMMENT ON COLUMN app_jobs.scheduled_jobs.id IS 'Auto-incrementing scheduled job identifier';
COMMENT ON COLUMN app_jobs.scheduled_jobs.database_id IS 'Database this scheduled job belongs to; every scheduled job is owned by exactly one database';
COMMENT ON COLUMN app_jobs.scheduled_jobs.actor_id IS 'User who created this scheduled job, read from JWT claims at creation time';
COMMENT ON COLUMN app_jobs.scheduled_jobs.principal_id IS 'Principal that triggered this scheduled job; equals actor_id for human-triggered jobs, differs when an agent/API-key acts on behalf of a user';
COMMENT ON COLUMN app_jobs.scheduled_jobs.entity_id IS 'Entity this scheduled job is attributed to for billing; read from the transaction entity claim at registration time; NULL means the claim was absent, not platform-level';
COMMENT ON COLUMN app_jobs.scheduled_jobs.organization_id IS 'Organization this scheduled job is attributed to; resolved from the entity pair via get_organization_id at registration time by callers that know it (e.g. data-job triggers) — never read from a claim';
COMMENT ON COLUMN app_jobs.scheduled_jobs.entity_type IS 'Entity type prefix (org, team, app, etc.) for interpreting entity_id';
COMMENT ON COLUMN app_jobs.scheduled_jobs.queue_name IS 'Name of the queue spawned jobs are placed into';
COMMENT ON COLUMN app_jobs.scheduled_jobs.task_identifier IS 'Task type identifier for spawned jobs';
COMMENT ON COLUMN app_jobs.scheduled_jobs.payload IS 'JSON payload passed to each spawned job';
COMMENT ON COLUMN app_jobs.scheduled_jobs.priority IS 'Priority assigned to spawned jobs (lower = higher priority)';
COMMENT ON COLUMN app_jobs.scheduled_jobs.max_attempts IS 'Max retry attempts for spawned jobs';
COMMENT ON COLUMN app_jobs.scheduled_jobs.key IS 'Optional unique deduplication key';
COMMENT ON COLUMN app_jobs.scheduled_jobs.locked_at IS 'Timestamp when the scheduler locked this record for processing';
COMMENT ON COLUMN app_jobs.scheduled_jobs.locked_by IS 'Identifier of the scheduler worker holding the lock';
COMMENT ON COLUMN app_jobs.scheduled_jobs.schedule_info IS 'JSON schedule configuration (e.g. cron expression, interval)';
COMMENT ON COLUMN app_jobs.scheduled_jobs.last_scheduled IS 'Timestamp when a job was last spawned from this schedule';
COMMENT ON COLUMN app_jobs.scheduled_jobs.last_scheduled_id IS 'ID of the last job spawned from this schedule';

COMMIT;
