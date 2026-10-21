-- Deploy schemas/jwt_public/procedures/current_principal_id to pg
-- Retrieves the current principal's ID from JWT claims with validation

-- requires: schemas/jwt_public/schema

BEGIN;

-- Returns the current principal's UUID from the JWT claims
-- Returns NULL if the claim is not set or empty; a malformed claim raises
-- (invalid_text_representation) rather than reading as absent.
-- LEAKPROOF: no arguments, so an error can only echo the caller's own claim.
CREATE FUNCTION jwt_public.current_principal_id()
  RETURNS uuid
AS $$
  SELECT nullif(current_setting('jwt.claims.principal_id', TRUE), '')::uuid;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

GRANT EXECUTE ON FUNCTION jwt_public.current_principal_id() TO authenticated;

COMMIT;
