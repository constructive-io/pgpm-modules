-- Revert schemas/function_resolution/procedures/validate_capabilities from pg

BEGIN;

DROP FUNCTION function_resolution.validate_capabilities(uuid, text, uuid, uuid, text, uuid, jsonb, text);

COMMIT;
