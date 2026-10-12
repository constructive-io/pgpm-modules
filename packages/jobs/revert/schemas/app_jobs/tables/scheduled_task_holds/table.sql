-- Revert schemas/app_jobs/tables/scheduled_task_holds/table from pg

BEGIN;

DROP TABLE app_jobs.scheduled_task_holds;

COMMIT;
