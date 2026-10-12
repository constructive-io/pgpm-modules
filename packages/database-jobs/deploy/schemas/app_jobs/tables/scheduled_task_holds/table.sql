-- Deploy schemas/app_jobs/tables/scheduled_task_holds/table to pg
-- requires: schemas/app_jobs/schema

BEGIN;
-- A task identifier listed here does not fire from any schedule: its
-- scheduled_jobs rows are dormant (next_run_at NULL), so the clock's due probe
-- never selects them and no job is spawned. hold_scheduled_task /
-- release_scheduled_task are the only writers.
CREATE TABLE app_jobs.scheduled_task_holds (
  task_identifier text PRIMARY KEY,
  reason text,
  held_at timestamptz DEFAULT now() NOT NULL,
  CHECK (length(task_identifier) < 127)
);

COMMENT ON TABLE app_jobs.scheduled_task_holds IS 'Task identifiers whose recurring schedules are held dormant: their scheduled_jobs rows keep next_run_at NULL and spawn no jobs until released';
COMMENT ON COLUMN app_jobs.scheduled_task_holds.task_identifier IS 'Task identifier whose schedules are held';
COMMENT ON COLUMN app_jobs.scheduled_task_holds.reason IS 'Why the task is held, as reported by whoever placed the hold';
COMMENT ON COLUMN app_jobs.scheduled_task_holds.held_at IS 'When the hold was first placed';
COMMIT;
