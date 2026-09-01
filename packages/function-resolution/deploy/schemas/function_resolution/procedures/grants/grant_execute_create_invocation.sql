-- Deploy schemas/function_resolution/procedures/grants/grant_execute_create_invocation to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/create_invocation

BEGIN;

-- The request roles reach exactly one function in this schema. Schema USAGE is
-- not a widening: pgpm-defaults revokes EXECUTE on new functions from PUBLIC and
-- this schema grants it only to administrator, so the sibling resolver functions
-- stay unreachable and the grant below is the whole surface.
GRANT USAGE ON SCHEMA function_resolution TO anonymous;

GRANT EXECUTE ON FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid) TO anonymous;

COMMIT;
