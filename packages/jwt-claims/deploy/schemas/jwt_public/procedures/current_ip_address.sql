-- Deploy schemas/jwt_public/procedures/current_ip_address to pg
-- Retrieves the client's IP address from JWT claims with validation

-- requires: schemas/jwt_public/schema

BEGIN;

-- Returns the client's IP address from the JWT claims
-- Returns NULL if the claim is not set or empty; a malformed claim raises
-- (invalid_text_representation) rather than reading as "no IP". Still
-- LEAKPROOF: it takes no arguments, so the error can only echo the caller's
-- own claim, never a row value an RLS qual is filtering.
CREATE FUNCTION jwt_public.current_ip_address()
  RETURNS inet
AS $$
  SELECT nullif(trim(current_setting('jwt.claims.ip_address', TRUE)), '')::inet;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

GRANT EXECUTE ON FUNCTION jwt_public.current_ip_address() TO authenticated;

-- Anonymous requests call the generated auth-schema reader, which is
-- SECURITY INVOKER and reaches this function as anonymous.
GRANT EXECUTE ON FUNCTION jwt_public.current_ip_address() TO anonymous;

COMMIT;
