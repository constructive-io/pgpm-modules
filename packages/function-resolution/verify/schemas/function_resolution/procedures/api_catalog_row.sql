-- Verify schemas/function_resolution/procedures/api_catalog_row  on pg

BEGIN;

SELECT assert_function('function_resolution.api_catalog_row(uuid, text, uuid, uuid)'::regprocedure);

ROLLBACK;
