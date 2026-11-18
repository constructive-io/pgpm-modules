-- Verify schemas/function_resolution/procedures/compute_entry  on pg

BEGIN;

SELECT assert_function('function_resolution.compute_entry(uuid)'::regprocedure);

ROLLBACK;
