-- Deploy schemas/app_jobs/tables/jobs/indexes/priority_run_at_id_idx to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/jobs/table

BEGIN;

-- get_job orders claims by (priority, run_at, id); id is a key column so a
-- backlog sharing one run_at is walked in index order rather than sorted.
CREATE INDEX jobs_main_index
  ON app_jobs.jobs USING btree (priority, run_at, id)
  INCLUDE (queue_name)
  WHERE (attempts < max_attempts);

CREATE INDEX jobs_no_queue_index
  ON app_jobs.jobs USING btree (priority, run_at, id)
  WHERE (attempts < max_attempts AND queue_name IS NULL);

COMMIT;
