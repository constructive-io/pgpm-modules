-- Deploy schemas/jwt_public/procedures/current_user_id to pg
-- Retrieves the current user's ID from JWT claims with validation

-- requires: schemas/jwt_public/schema

BEGIN;

-- Returns NULL if the claim is not set, empty, or not a valid UUID
-- pg_input_is_valid() validates without raising, so no EXCEPTION block is
-- needed: an exception handler would open a subtransaction on every call
CREATE FUNCTION jwt_public.current_user_id()
  RETURNS uuid
AS $$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.user_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.user_id', TRUE)::uuid
  END;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

COMMIT;
