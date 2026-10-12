-- Verify schemas/function_resolution/procedures/fire_due_scheduled_jobs  on pg

BEGIN;

SELECT assert_function('function_resolution.fire_due_scheduled_jobs(integer, interval)'::regprocedure);

ROLLBACK;
