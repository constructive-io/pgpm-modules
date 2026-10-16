-- Verify schemas/app_jobs/procedures/scheduled_task_identifiers on pg

BEGIN;

SELECT assert_function('app_jobs.scheduled_task_identifiers(uuid)'::regprocedure);

ROLLBACK;
