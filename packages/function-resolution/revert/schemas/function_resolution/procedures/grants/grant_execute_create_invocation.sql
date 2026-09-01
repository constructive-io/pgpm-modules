-- Revert schemas/function_resolution/procedures/grants/grant_execute_create_invocation from pg

BEGIN;

REVOKE EXECUTE ON FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid) FROM anonymous;
REVOKE EXECUTE ON FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid) FROM authenticated;

REVOKE USAGE ON SCHEMA function_resolution FROM anonymous;

COMMIT;
