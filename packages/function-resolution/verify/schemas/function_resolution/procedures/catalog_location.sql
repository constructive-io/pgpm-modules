-- Verify schemas/function_resolution/procedures/catalog_location  on pg

BEGIN;

SELECT verify_function ('function_resolution.catalog_location');

ROLLBACK;
