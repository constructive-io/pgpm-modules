-- Deploy schemas/jwt_private/procedures/require_entity_type to pg
-- Retrieves the required entity type from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- This strict reader is deliberately not LEAKPROOF so PostgreSQL cannot push
-- its raising claim check into an RLS security barrier.
CREATE FUNCTION jwt_private.require_entity_type()
  RETURNS text
AS $$
DECLARE
  entity_type text;
BEGIN
  entity_type = NULLIF(current_setting('jwt.claims.entity_type', TRUE), '');
  IF entity_type IS NULL THEN
    PERFORM errors.raise_error(
      'ENTITY_TYPE_CLAIM_REQUIRED',
      jsonb_build_object('claim', 'jwt.claims.entity_type'),
      'internal'
    );
  END IF;
  RETURN entity_type;
END;
$$
LANGUAGE 'plpgsql' STABLE PARALLEL SAFE;

COMMIT;
