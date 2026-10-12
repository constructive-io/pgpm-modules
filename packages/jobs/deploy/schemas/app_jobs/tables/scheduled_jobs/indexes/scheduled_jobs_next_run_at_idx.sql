-- Deploy schemas/app_jobs/tables/scheduled_jobs/indexes/scheduled_jobs_next_run_at_idx to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table

BEGIN;
CREATE INDEX scheduled_jobs_next_run_at_idx ON app_jobs.scheduled_jobs (next_run_at);
COMMIT;
