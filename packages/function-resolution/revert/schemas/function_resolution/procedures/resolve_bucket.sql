-- Revert schemas/function_resolution/procedures/resolve_bucket from pg

BEGIN;

DROP FUNCTION function_resolution.resolve_bucket(uuid, text, uuid, text[], text);

COMMIT;
