-- Deploy schemas/jwt_private/procedures/current_database_id to pg
-- Retrieves the current database ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- pg_input_is_valid() validates without raising, so no EXCEPTION block is
-- needed: an exception handler would open a subtransaction on every call
-- LEAKPROOF is safe here: with no arguments, this function cannot reveal
-- anything about the row a policy is testing, so claim comparisons can be pushed down.
CREATE FUNCTION jwt_private.current_database_id()
  RETURNS uuid
AS $$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.database_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.database_id', TRUE)::uuid
  END;
$$
LANGUAGE 'sql' STABLE LEAKPROOF PARALLEL SAFE;

COMMIT;
