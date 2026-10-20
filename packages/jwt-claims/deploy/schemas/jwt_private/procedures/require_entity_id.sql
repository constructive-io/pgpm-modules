-- Deploy schemas/jwt_private/procedures/require_entity_id to pg
-- Retrieves the required entity ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- This strict reader is deliberately not LEAKPROOF so PostgreSQL cannot push
-- its raising claim check into an RLS security barrier.
CREATE FUNCTION jwt_private.require_entity_id()
  RETURNS uuid
AS $$
DECLARE
  entity_id uuid;
BEGIN
  -- Absent or empty raises the claim-required error below; a malformed claim
  -- raises invalid_text_representation here.
  entity_id = nullif(current_setting('jwt.claims.entity_id', TRUE), '')::uuid;
  IF entity_id IS NULL THEN
    PERFORM errors.raise_error(
      'ENTITY_CLAIM_REQUIRED',
      jsonb_build_object('claim', 'jwt.claims.entity_id'),
      'internal'
    );
  END IF;
  RETURN entity_id;
END;
$$
LANGUAGE 'plpgsql' STABLE PARALLEL SAFE;

COMMIT;
