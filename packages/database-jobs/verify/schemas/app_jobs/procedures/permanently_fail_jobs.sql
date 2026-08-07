-- Verify schemas/app_jobs/procedures/permanently_fail_jobs  on pg

BEGIN;

SELECT assert_function('app_jobs.permanently_fail_jobs(int8[], text)'::regprocedure);

ROLLBACK;
