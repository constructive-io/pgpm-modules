-- Revert schemas/function_resolution/procedures/image_catalog_row from pg

BEGIN;

DROP FUNCTION function_resolution.image_catalog_row(uuid, text, uuid, text);

COMMIT;
