-- Revert schemas/function_resolution/procedures/database_export_catalog from pg

BEGIN;

DROP FUNCTION function_resolution.database_export_catalog(uuid);

COMMIT;
