-- Deploy schemas/jwt_public/procedures/require_user_id to pg
-- Retrieves the required user ID from JWT claims

-- requires: schemas/jwt_public/schema

BEGIN;

-- This strict reader is deliberately not LEAKPROOF so PostgreSQL cannot push
-- its raising claim check into an RLS security barrier.
CREATE FUNCTION jwt_public.require_user_id()
  RETURNS uuid
AS $$
DECLARE
  user_id uuid;
BEGIN
  -- Absent or empty raises the claim-required error below; a malformed claim
  -- raises invalid_text_representation here.
  user_id = nullif(current_setting('jwt.claims.user_id', TRUE), '')::uuid;
  IF user_id IS NULL THEN
    PERFORM errors.raise_error(
      'ACTOR_CLAIM_REQUIRED',
      jsonb_build_object('claim', 'jwt.claims.user_id'),
      'internal'
    );
  END IF;
  RETURN user_id;
END;
$$
LANGUAGE 'plpgsql' STABLE PARALLEL SAFE;

GRANT EXECUTE ON FUNCTION jwt_public.require_user_id() TO authenticated;

COMMIT;
