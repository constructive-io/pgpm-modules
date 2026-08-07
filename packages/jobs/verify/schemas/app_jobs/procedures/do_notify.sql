-- Verify schemas/app_jobs/procedures/do_notify  on pg

BEGIN;

SELECT assert_function('app_jobs.do_notify()'::regprocedure);

ROLLBACK;
