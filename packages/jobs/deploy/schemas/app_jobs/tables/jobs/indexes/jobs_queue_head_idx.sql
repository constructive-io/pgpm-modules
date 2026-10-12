-- Deploy schemas/app_jobs/tables/jobs/indexes/jobs_queue_head_idx to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/jobs/table

BEGIN;

-- get_job stamps a named queue only if the job it chose is still that queue's
-- first claimable job: that check is one descent of this index.
CREATE INDEX jobs_queue_head_idx
  ON app_jobs.jobs USING btree (queue_name, priority, run_at, id)
  WHERE (queue_name IS NOT NULL);

COMMIT;
