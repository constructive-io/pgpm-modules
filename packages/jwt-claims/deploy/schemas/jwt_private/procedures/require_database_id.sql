-- Deploy schemas/jwt_private/procedures/require_database_id to pg
-- Retrieves the required database ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- This strict reader is deliberately not LEAKPROOF so PostgreSQL cannot push
-- its raising claim check into an RLS security barrier.
CREATE FUNCTION jwt_private.require_database_id()
  RETURNS uuid
AS $$
DECLARE
  database_id uuid;
BEGIN
  -- Absent or empty raises the claim-required error below; a malformed claim
  -- raises invalid_text_representation here.
  database_id = nullif(current_setting('jwt.claims.database_id', TRUE), '')::uuid;
  IF database_id IS NULL THEN
    PERFORM errors.raise_error(
      'DATABASE_CLAIM_REQUIRED',
      jsonb_build_object('claim', 'jwt.claims.database_id'),
      'internal'
    );
  END IF;
  RETURN database_id;
END;
$$
LANGUAGE 'plpgsql' STABLE PARALLEL SAFE;

COMMIT;
