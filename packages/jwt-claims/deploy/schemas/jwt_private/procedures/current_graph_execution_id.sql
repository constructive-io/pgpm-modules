-- Deploy schemas/jwt_private/procedures/current_graph_execution_id to pg
-- Retrieves the current graph execution ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- Returns NULL if the claim is not set or empty; a malformed claim raises
-- (invalid_text_representation) rather than reading as absent.
-- LEAKPROOF: no arguments, so an error can only echo the caller's own claim.
CREATE FUNCTION jwt_private.current_graph_execution_id()
  RETURNS uuid
AS $$
  SELECT nullif(current_setting('jwt.claims.graph_execution_id', TRUE), '')::uuid;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

COMMIT;
