-- Revert schemas/function_resolution/procedures/resolve_default_bucket from pg

BEGIN;

DROP FUNCTION function_resolution.resolve_default_bucket(text, uuid, boolean, text);

COMMIT;
