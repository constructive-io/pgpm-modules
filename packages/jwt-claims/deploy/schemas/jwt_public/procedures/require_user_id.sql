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
  IF pg_input_is_valid(current_setting('jwt.claims.user_id', TRUE), 'uuid') THEN
    user_id = current_setting('jwt.claims.user_id', TRUE)::uuid;
  END IF;
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

COMMIT;
