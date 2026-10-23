-- Deploy schemas/jwt_public/procedures/current_user_agent to pg
-- Retrieves the client's user agent string from JWT claims

-- requires: schemas/jwt_public/schema

BEGIN;

-- Returns the client's user agent string from the JWT claims
-- Returns NULL if the claim is not set or empty: a pooled connection that once
-- stamped the claim keeps the GUC defined, so an unset claim reads '' there and
-- NULL on a fresh connection; nullif makes both read as "no user agent". The
-- value needs no cast, so it can never raise and needs no EXCEPTION block
-- (which would open a subtransaction)
CREATE FUNCTION jwt_public.current_user_agent()
  RETURNS text
AS $$
  SELECT nullif(current_setting('jwt.claims.user_agent', TRUE), '');
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

GRANT EXECUTE ON FUNCTION jwt_public.current_user_agent() TO authenticated;

-- Anonymous requests call the generated auth-schema reader, which is
-- SECURITY INVOKER and reaches this function as anonymous.
GRANT EXECUTE ON FUNCTION jwt_public.current_user_agent() TO anonymous;

COMMIT;
