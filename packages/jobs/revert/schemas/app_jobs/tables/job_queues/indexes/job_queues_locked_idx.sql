-- Revert schemas/app_jobs/tables/job_queues/indexes/job_queues_locked_idx from pg

BEGIN;

DROP INDEX app_jobs.job_queues_locked_idx;

COMMIT;
