-- Deploy schemas/jwt_private/procedures/current_entity_id to pg
-- Retrieves the current entity ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- Returns NULL if the claim is not set, empty, or not a valid UUID
CREATE FUNCTION jwt_private.current_entity_id()
  RETURNS uuid
AS $$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.entity_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.entity_id', TRUE)::uuid
  END;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

COMMIT;
