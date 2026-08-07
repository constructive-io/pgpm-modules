-- Revert schemas/function_resolution/procedures/api_catalog_row from pg

BEGIN;

DROP FUNCTION function_resolution.api_catalog_row(uuid, text, uuid, uuid);

COMMIT;
