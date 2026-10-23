-- Deploy schemas/jwt_private/procedures/current_database_id to pg
-- Retrieves the current database ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- LEAKPROOF is safe here: with no arguments, this function cannot reveal
-- anything about the row a policy is testing, so claim comparisons can be pushed down.
CREATE FUNCTION jwt_private.current_database_id()
  RETURNS uuid
AS $$
  SELECT nullif(current_setting('jwt.claims.database_id', TRUE), '')::uuid;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

-- The schema default grants EXECUTE to authenticated only. Anonymous requests
-- also carry a database claim (the server sets it per request) and resolve it
-- here; the function only reads the caller's own GUC.
GRANT EXECUTE ON FUNCTION jwt_private.current_database_id() TO anonymous;

GRANT EXECUTE ON FUNCTION jwt_private.current_database_id() TO authenticated;

COMMIT;
