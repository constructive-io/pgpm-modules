-- Verify schemas/function_resolution/procedures/events_entry  on pg

BEGIN;

SELECT assert_function('function_resolution.events_entry(uuid)'::regprocedure);

ROLLBACK;
