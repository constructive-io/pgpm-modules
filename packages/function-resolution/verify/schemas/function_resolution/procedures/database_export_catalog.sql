-- Verify schemas/function_resolution/procedures/database_export_catalog  on pg

BEGIN;

SELECT assert_function('function_resolution.database_export_catalog(uuid)'::regprocedure);

ROLLBACK;
