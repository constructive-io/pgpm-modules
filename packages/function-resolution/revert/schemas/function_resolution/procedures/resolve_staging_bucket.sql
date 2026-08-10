-- Revert schemas/function_resolution/procedures/resolve_staging_bucket from pg

BEGIN;

DROP FUNCTION function_resolution.resolve_staging_bucket(uuid, text, uuid);

COMMIT;
