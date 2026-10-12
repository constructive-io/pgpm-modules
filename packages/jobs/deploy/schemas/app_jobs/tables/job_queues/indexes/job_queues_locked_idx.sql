-- Deploy schemas/app_jobs/tables/job_queues/indexes/job_queues_locked_idx to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/job_queues/table

BEGIN;

-- get_job asks "is this queue locked right now?"; only locked rows are indexed,
-- so a free queue costs nothing and a lock stamp touches one small index.
CREATE INDEX job_queues_locked_idx
  ON app_jobs.job_queues USING btree (queue_name)
  WHERE (locked_at IS NOT NULL);

COMMIT;
