-- Deploy schemas/jwt_public/procedures/current_role_type to pg
-- Retrieves the current role type from JWT claims (defaults to 'user')

-- requires: schemas/jwt_public/schema

BEGIN;

-- Returns the current role type from the JWT claims
-- Defaults to 'user' for normal API requests
-- System operations (triggers, workers) set this to 'system'
CREATE FUNCTION jwt_public.current_role_type()
  RETURNS text
AS $$
  SELECT coalesce(nullif(current_setting('jwt.claims.role_type', TRUE), ''), 'user');
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

COMMIT;
