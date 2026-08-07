-- Verify schemas/function_resolution/procedures/bucket_catalog_row  on pg

BEGIN;

SELECT assert_function('function_resolution.bucket_catalog_row(uuid, text, uuid, uuid)'::regprocedure);

ROLLBACK;
