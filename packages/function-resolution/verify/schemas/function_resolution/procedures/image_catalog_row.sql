-- Verify schemas/function_resolution/procedures/image_catalog_row  on pg

BEGIN;

SELECT assert_function('function_resolution.image_catalog_row(uuid, text, uuid, text)'::regprocedure);

ROLLBACK;
