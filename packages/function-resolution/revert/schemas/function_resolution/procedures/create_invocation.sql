-- Revert schemas/function_resolution/procedures/create_invocation from pg

BEGIN;

DROP FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid);

COMMIT;
