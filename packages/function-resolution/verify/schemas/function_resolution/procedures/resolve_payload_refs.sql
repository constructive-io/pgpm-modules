-- Verify schemas/function_resolution/procedures/resolve_payload_refs  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_payload_refs(uuid, text, uuid, jsonb)'::regprocedure);

ROLLBACK;
