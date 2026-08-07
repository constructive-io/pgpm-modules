-- Revert schemas/function_resolution/procedures/resolve_capabilities from pg

BEGIN;

DROP FUNCTION function_resolution.resolve_capabilities(uuid, text, uuid, uuid, text, uuid, jsonb, text);

COMMIT;
