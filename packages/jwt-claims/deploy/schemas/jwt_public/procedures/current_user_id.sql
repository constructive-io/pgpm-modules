-- Deploy schemas/jwt_public/procedures/current_user_id to pg
-- Retrieves the current user's ID from JWT claims with validation

-- requires: schemas/jwt_public/schema

BEGIN;

-- Returns NULL if the claim is not set or empty; a malformed claim raises
-- (invalid_text_representation) rather than reading as "no user". Still
-- LEAKPROOF: it takes no arguments, so the error can only echo the caller's
-- own claim, never a row value an RLS qual is filtering.
CREATE FUNCTION jwt_public.current_user_id()
  RETURNS uuid
AS $$
  SELECT nullif(current_setting('jwt.claims.user_id', TRUE), '')::uuid;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

GRANT EXECUTE ON FUNCTION jwt_public.current_user_id() TO authenticated;

-- Anonymous requests call the generated auth-schema reader, which is
-- SECURITY INVOKER and reaches this function as anonymous.
GRANT EXECUTE ON FUNCTION jwt_public.current_user_id() TO anonymous;

COMMIT;
