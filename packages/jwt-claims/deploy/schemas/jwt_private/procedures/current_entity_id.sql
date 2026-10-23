-- Deploy schemas/jwt_private/procedures/current_entity_id to pg
-- Retrieves the current entity ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- Returns NULL if the claim is not set or empty; a malformed claim raises
-- (invalid_text_representation) rather than reading as absent.
-- LEAKPROOF: no arguments, so an error can only echo the caller's own claim.
CREATE FUNCTION jwt_private.current_entity_id()
  RETURNS uuid
AS $$
  SELECT nullif(current_setting('jwt.claims.entity_id', TRUE), '')::uuid;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

GRANT EXECUTE ON FUNCTION jwt_private.current_entity_id() TO authenticated;

COMMIT;
