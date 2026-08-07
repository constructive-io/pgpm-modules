-- Revert schemas/function_resolution/procedures/resolve from pg

BEGIN;

DROP FUNCTION function_resolution.resolve(uuid, text, uuid, text, bool);

COMMIT;
