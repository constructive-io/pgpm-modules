-- Revert schemas/function_resolution/procedures/api_by_name from pg

BEGIN;

DROP FUNCTION function_resolution.api_by_name(uuid, text);

COMMIT;
