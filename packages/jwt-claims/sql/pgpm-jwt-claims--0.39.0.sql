\echo Use "CREATE EXTENSION pgpm-jwt-claims" to load this file. \quit
CREATE SCHEMA ctx;

GRANT USAGE ON SCHEMA ctx TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA ctx
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

CREATE FUNCTION ctx.ip_address() RETURNS inet AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.ip_address', true), '')::inet;
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION ctx.origin() RETURNS origin AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.origin', true), '')::origin;
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION ctx.uagent() RETURNS text AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.user_agent', true), '');
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION ctx.uid() RETURNS uuid AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.user_id', true), '')::uuid;
$EOFCODE$ LANGUAGE sql STABLE;

DO $EOFCODE$
  DECLARE
  BEGIN
    EXECUTE format('CREATE FUNCTION ctx.security_definer() returns text as $FUNC$
      SELECT ''%s'';
$FUNC$
LANGUAGE ''sql'';', current_user);
    EXECUTE format('CREATE FUNCTION ctx.is_security_definer() returns bool as $FUNC$
      SELECT ''%s'' = current_user;
$FUNC$
LANGUAGE ''sql'';', current_user);
  END;
$EOFCODE$;

GRANT EXECUTE ON FUNCTION ctx.security_definer() TO PUBLIC;

GRANT EXECUTE ON FUNCTION ctx.is_security_definer() TO PUBLIC;

CREATE SCHEMA jwt_public;

GRANT USAGE ON SCHEMA jwt_public TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA jwt_public
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

CREATE FUNCTION jwt_public.current_user_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.user_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.user_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF;

CREATE FUNCTION jwt_public.current_ip_address() RETURNS inet AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(trim(current_setting('jwt.claims.ip_address', TRUE)), 'inet')
      THEN trim(current_setting('jwt.claims.ip_address', TRUE))::inet
  END;
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION jwt_public.current_user_agent() RETURNS text AS $EOFCODE$
  SELECT current_setting('jwt.claims.user_agent', TRUE);
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION jwt_public.current_origin() RETURNS origin AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.origin', true), '')::origin;
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION jwt_public.current_principal_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.principal_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.principal_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF;

CREATE FUNCTION jwt_public.current_role_type() RETURNS text AS $EOFCODE$
  SELECT coalesce(nullif(current_setting('jwt.claims.role_type', TRUE), ''), 'user');
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF;

CREATE SCHEMA jwt_private;

GRANT USAGE ON SCHEMA jwt_private TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA jwt_private
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

CREATE FUNCTION jwt_private.current_database_id() RETURNS uuid AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION jwt_private.current_token_id() RETURNS uuid AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.token_id', true), '')::uuid;
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION jwt_private.current_session_id() RETURNS uuid AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.session_id', true), '')::uuid;
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION jwt_private.current_api_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.api_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.api_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF;

CREATE FUNCTION jwt_private.current_graph_execution_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.graph_execution_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.graph_execution_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF;