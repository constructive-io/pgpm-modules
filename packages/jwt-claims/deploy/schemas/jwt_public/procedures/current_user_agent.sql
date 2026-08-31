-- Deploy schemas/jwt_public/procedures/current_user_agent to pg
-- Retrieves the client's user agent string from JWT claims

-- requires: schemas/jwt_public/schema

BEGIN;

-- Returns the client's user agent string from the JWT claims
-- Returns NULL if the claim is not set; the value needs no cast, so it can
-- never raise and needs no EXCEPTION block (which would open a subtransaction)
CREATE FUNCTION jwt_public.current_user_agent()
  RETURNS text
AS $$
  SELECT current_setting('jwt.claims.user_agent', TRUE);
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

COMMIT;
