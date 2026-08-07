-- Revert schemas/function_resolution/procedures/resolve_payload_refs from pg

BEGIN;

DROP FUNCTION function_resolution.resolve_payload_refs(uuid, text, uuid, jsonb);

COMMIT;
