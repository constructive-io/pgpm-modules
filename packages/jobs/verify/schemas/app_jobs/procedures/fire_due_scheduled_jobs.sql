-- Verify schemas/app_jobs/procedures/fire_due_scheduled_jobs  on pg

BEGIN;

SELECT assert_function('app_jobs.fire_due_scheduled_jobs(integer)'::regprocedure);

ROLLBACK;
