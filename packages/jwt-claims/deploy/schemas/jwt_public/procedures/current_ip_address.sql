-- Deploy schemas/jwt_public/procedures/current_ip_address to pg
-- Retrieves the client's IP address from JWT claims with validation

-- requires: schemas/jwt_public/schema

BEGIN;

-- Returns the client's IP address from the JWT claims
-- Returns NULL if the claim is not set, empty, or not a valid inet value
-- pg_input_is_valid() validates without raising, so no EXCEPTION block is
-- needed: an exception handler would open a subtransaction on every call
CREATE FUNCTION jwt_public.current_ip_address()
  RETURNS inet
AS $$
  SELECT CASE
    WHEN pg_input_is_valid(trim(current_setting('jwt.claims.ip_address', TRUE)), 'inet')
      THEN trim(current_setting('jwt.claims.ip_address', TRUE))::inet
  END;
$$
LANGUAGE 'sql' STABLE;

COMMIT;
