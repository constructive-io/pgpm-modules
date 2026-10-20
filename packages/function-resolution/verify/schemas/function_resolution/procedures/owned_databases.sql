-- Verify schemas/function_resolution/procedures/owned_databases  on pg

BEGIN;

SELECT assert_function('function_resolution.owned_databases(uuid[])'::regprocedure);

ROLLBACK;
