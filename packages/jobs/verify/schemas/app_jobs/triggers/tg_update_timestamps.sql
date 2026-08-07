-- Verify schemas/app_jobs/triggers/tg_update_timestamps  on pg

BEGIN;

SELECT assert_function('app_jobs.tg_update_timestamps()'::regprocedure);

ROLLBACK;
