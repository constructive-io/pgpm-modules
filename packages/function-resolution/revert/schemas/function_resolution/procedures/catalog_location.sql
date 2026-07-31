-- Revert schemas/function_resolution/procedures/catalog_location from pg

BEGIN;

DROP FUNCTION function_resolution.catalog_location;

COMMIT;
