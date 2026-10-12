-- Verify schemas/app_jobs/procedures/schedule_next_run  on pg

BEGIN;

SELECT assert_function('app_jobs.schedule_next_run(json, timestamptz)'::regprocedure);
SELECT assert_function('app_jobs.recurrence_field_values(json, int, int)'::regprocedure);

ROLLBACK;
