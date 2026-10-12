-- Deploy schemas/app_jobs/tables/scheduled_jobs/table to pg
-- requires: schemas/app_jobs/schema

BEGIN;
CREATE TABLE app_jobs.scheduled_jobs (
  id bigserial PRIMARY KEY,
  queue_name text DEFAULT (public.gen_random_uuid ()) ::text,
  task_identifier text NOT NULL,
  payload json DEFAULT '{}' ::json NOT NULL,
  priority integer DEFAULT 0 NOT NULL,
  max_attempts integer DEFAULT 25 NOT NULL,
  key text,
  schedule_info json NOT NULL,
  next_run_at timestamptz,
  last_error text,
  last_error_at timestamptz,
  last_scheduled timestamptz,
  last_scheduled_id bigint,
  CHECK (length(key) < 513),
  CHECK (length(task_identifier) < 127),
  CHECK (max_attempts > 0),
  CHECK (length(queue_name) < 127),
  UNIQUE (key)
);

COMMENT ON TABLE app_jobs.scheduled_jobs IS 'Recurring/cron-style job definitions: each row spawns jobs on a schedule defined by schedule_info';
COMMENT ON COLUMN app_jobs.scheduled_jobs.id IS 'Auto-incrementing scheduled job identifier';
COMMENT ON COLUMN app_jobs.scheduled_jobs.queue_name IS 'Name of the queue spawned jobs are placed into';
COMMENT ON COLUMN app_jobs.scheduled_jobs.task_identifier IS 'Task type identifier for spawned jobs';
COMMENT ON COLUMN app_jobs.scheduled_jobs.payload IS 'JSON payload passed to each spawned job';
COMMENT ON COLUMN app_jobs.scheduled_jobs.priority IS 'Priority assigned to spawned jobs (lower = higher priority)';
COMMENT ON COLUMN app_jobs.scheduled_jobs.max_attempts IS 'Max retry attempts for spawned jobs';
COMMENT ON COLUMN app_jobs.scheduled_jobs.key IS 'Optional unique deduplication key';
COMMENT ON COLUMN app_jobs.scheduled_jobs.schedule_info IS 'JSON schedule configuration (e.g. cron expression, interval)';
COMMENT ON COLUMN app_jobs.scheduled_jobs.last_scheduled IS 'Timestamp when a job was last spawned from this schedule';
COMMENT ON COLUMN app_jobs.scheduled_jobs.last_scheduled_id IS 'ID of the last job spawned from this schedule';

COMMENT ON COLUMN app_jobs.scheduled_jobs.next_run_at IS 'Next instant this schedule fires, computed from schedule_info by app_jobs.schedule_next_run; app_jobs.fire_due_scheduled_jobs, called on a fixed interval by the schedule clock, fires every row whose next_run_at has passed';
COMMENT ON COLUMN app_jobs.scheduled_jobs.last_error IS 'Error raised the last time fire_due_scheduled_jobs tried to spawn this schedule; cleared when a spawn succeeds';
COMMENT ON COLUMN app_jobs.scheduled_jobs.last_error_at IS 'When last_error was recorded';

COMMIT;

