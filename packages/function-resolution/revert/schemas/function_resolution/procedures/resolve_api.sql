-- Revert schemas/function_resolution/procedures/resolve_api from pg

BEGIN;

DROP FUNCTION function_resolution.resolve_api(uuid, text, uuid, text);

COMMIT;
