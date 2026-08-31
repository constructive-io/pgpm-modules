-- Deploy schemas/jwt_private/procedures/current_graph_execution_id to pg
-- Retrieves the current graph execution ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- Returns NULL if the claim is not set, empty, or not a valid UUID
-- pg_input_is_valid() validates without raising, so no EXCEPTION block is
-- needed: an exception handler would open a subtransaction on every call
CREATE FUNCTION jwt_private.current_graph_execution_id()
  RETURNS uuid
AS $$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.graph_execution_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.graph_execution_id', TRUE)::uuid
  END;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

COMMIT;
