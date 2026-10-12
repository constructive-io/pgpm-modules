-- Revert schemas/app_jobs/tables/jobs/indexes/jobs_queue_head_idx from pg

BEGIN;

DROP INDEX app_jobs.jobs_queue_head_idx;

COMMIT;
