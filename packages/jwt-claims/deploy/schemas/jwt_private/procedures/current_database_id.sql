-- Deploy schemas/jwt_private/procedures/current_database_id to pg
-- Retrieves the current database ID from JWT claims (private/internal use)

-- requires: schemas/jwt_private/schema

BEGIN;

-- Returns the current database UUID from the JWT claims
-- Used for multi-tenant database isolation
--
-- The claim is set at every session boundary (API, worker, provisioning,
-- platform deploy/seed), so a missing or malformed claim is never a
-- legitimate state: it means a scoped write is about to run unattributed.
-- Fails loudly instead of returning NULL, so the omission surfaces at the
-- statement that needed the identity rather than as a NULL that travels.
--
-- pg_input_is_valid() validates without raising, so no EXCEPTION block is
-- needed: an exception handler would open a subtransaction on every call
--
-- LEAKPROOF like its sibling claim readers: it takes no arguments, so it can
-- leak nothing about the row a policy is testing, and the planner may push the
-- claim comparison down instead of treating every policy that reads a claim as
-- a barrier. Its one error path depends on the session, never on a value.
CREATE FUNCTION jwt_private.current_database_id()
  RETURNS uuid
AS $$
DECLARE
  database_id uuid;
BEGIN
  IF pg_input_is_valid(current_setting('jwt.claims.database_id', TRUE), 'uuid') THEN
    database_id = current_setting('jwt.claims.database_id', TRUE)::uuid;
  END IF;
  IF database_id IS NULL THEN
    PERFORM errors.raise_error(
      'DATABASE_CLAIM_REQUIRED',
      jsonb_build_object('claim', 'jwt.claims.database_id'),
      'internal'
    );
  END IF;
  RETURN database_id;
END;
$$
LANGUAGE 'plpgsql' STABLE LEAKPROOF;

COMMIT;
