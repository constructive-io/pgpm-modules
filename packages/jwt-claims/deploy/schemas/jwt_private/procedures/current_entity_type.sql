-- Deploy schemas/jwt_private/procedures/current_entity_type to pg
-- Retrieves the current entity type from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

CREATE FUNCTION jwt_private.current_entity_type()
  RETURNS text
AS $$
  SELECT NULLIF(current_setting('jwt.claims.entity_type', TRUE), '');
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

COMMIT;
