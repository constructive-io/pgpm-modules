-- Verify schemas/app_jobs/procedures/reschedule_jobs  on pg

BEGIN;

SELECT assert_function('app_jobs.reschedule_jobs(int8[], timestamptz, int4, int4, int4)'::regprocedure);

ROLLBACK;
