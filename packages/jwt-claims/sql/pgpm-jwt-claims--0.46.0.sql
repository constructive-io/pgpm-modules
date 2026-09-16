\echo Use "CREATE EXTENSION pgpm-jwt-claims" to load this file. \quit
CREATE SCHEMA ctx;

GRANT USAGE ON SCHEMA ctx TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA ctx
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

CREATE FUNCTION ctx.ip_address() RETURNS inet AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.ip_address', true), '')::inet;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION ctx.origin() RETURNS origin AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.origin', true), '')::origin;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION ctx.uagent() RETURNS text AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.user_agent', true), '');
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION ctx.uid() RETURNS uuid AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.user_id', true), '')::uuid;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

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
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_public.current_ip_address() RETURNS inet AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(trim(current_setting('jwt.claims.ip_address', TRUE)), 'inet')
      THEN trim(current_setting('jwt.claims.ip_address', TRUE))::inet
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_public.current_user_agent() RETURNS text AS $EOFCODE$
  SELECT current_setting('jwt.claims.user_agent', TRUE);
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_public.current_origin() RETURNS origin AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.origin', true), '')::origin;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_public.current_principal_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.principal_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.principal_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_public.current_role_type() RETURNS text AS $EOFCODE$
  SELECT coalesce(nullif(current_setting('jwt.claims.role_type', TRUE), ''), 'user');
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE SCHEMA jwt_private;

GRANT USAGE ON SCHEMA jwt_private TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA jwt_private
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

CREATE FUNCTION jwt_private.current_database_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.database_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.database_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_private.require_database_id() RETURNS uuid AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql STABLE PARALLEL safe;

CREATE FUNCTION jwt_private.current_token_id() RETURNS uuid AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.token_id', true), '')::uuid;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_private.current_session_id() RETURNS uuid AS $EOFCODE$
  SELECT nullif(current_setting('jwt.claims.session_id', true), '')::uuid;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_private.current_api_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.api_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.api_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_private.current_graph_execution_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.graph_execution_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.graph_execution_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_private.current_entity_id() RETURNS uuid AS $EOFCODE$
  SELECT CASE
    WHEN pg_input_is_valid(current_setting('jwt.claims.entity_id', TRUE), 'uuid')
      THEN current_setting('jwt.claims.entity_id', TRUE)::uuid
  END;
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_private.current_entity_type() RETURNS text AS $EOFCODE$
  SELECT NULLIF(current_setting('jwt.claims.entity_type', TRUE), '');
$EOFCODE$ LANGUAGE sql STABLE LEAKPROOF PARALLEL safe;

CREATE FUNCTION jwt_public.require_user_id() RETURNS uuid AS $EOFCODE$
DECLARE
  user_id uuid;
BEGIN
  IF pg_input_is_valid(current_setting('jwt.claims.user_id', TRUE), 'uuid') THEN
    user_id = current_setting('jwt.claims.user_id', TRUE)::uuid;
  END IF;
  IF user_id IS NULL THEN
    PERFORM errors.raise_error(
      'ACTOR_CLAIM_REQUIRED',
      jsonb_build_object('claim', 'jwt.claims.user_id'),
      'internal'
    );
  END IF;
  RETURN user_id;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE PARALLEL safe;

CREATE FUNCTION jwt_private.require_entity_id() RETURNS uuid AS $EOFCODE$
DECLARE
  entity_id uuid;
BEGIN
  IF pg_input_is_valid(current_setting('jwt.claims.entity_id', TRUE), 'uuid') THEN
    entity_id = current_setting('jwt.claims.entity_id', TRUE)::uuid;
  END IF;
  IF entity_id IS NULL THEN
    PERFORM errors.raise_error(
      'ENTITY_CLAIM_REQUIRED',
      jsonb_build_object('claim', 'jwt.claims.entity_id'),
      'internal'
    );
  END IF;
  RETURN entity_id;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE PARALLEL safe;

CREATE FUNCTION jwt_private.require_entity_type() RETURNS text AS $EOFCODE$
DECLARE
  entity_type text;
BEGIN
  entity_type = NULLIF(current_setting('jwt.claims.entity_type', TRUE), '');
  IF entity_type IS NULL THEN
    PERFORM errors.raise_error(
      'ENTITY_TYPE_CLAIM_REQUIRED',
      jsonb_build_object('claim', 'jwt.claims.entity_type'),
      'internal'
    );
  END IF;
  RETURN entity_type;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE PARALLEL safe;

CREATE FUNCTION jwt_private.assert_attribution(
  actor_id uuid,
  entity_id uuid,
  entity_type text
) RETURNS void AS $EOFCODE$
DECLARE
  strict_attribution boolean :=
    COALESCE(
      NULLIF(current_setting('jwt.strict_attribution', true), ''),
      'true'
    ) <> 'false';
  context jsonb;
BEGIN
  IF actor_id IS NULL AND entity_id IS NULL THEN
    context := jsonb_build_object(
      'arguments', jsonb_build_array('actor_id', 'entity_id'),
      'claims', jsonb_build_array('jwt.claims.user_id', 'jwt.claims.entity_id')
    );
    IF strict_attribution THEN
      PERFORM errors.raise_error('ATTRIBUTION_REQUIRED', context, 'internal');
    ELSE
      RAISE WARNING '%',
        jsonb_build_object(
          'code', 'ATTRIBUTION_REQUIRED',
          'class', 'internal',
          'context', context
        );
    END IF;
  ELSIF entity_id IS NOT NULL AND entity_type IS NULL THEN
    context := jsonb_build_object(
      'argument', 'entity_type',
      'claim', 'jwt.claims.entity_type',
      'entity_id', entity_id
    );
    IF strict_attribution THEN
      PERFORM errors.raise_error('ENTITY_TYPE_REQUIRED', context, 'internal');
    ELSE
      RAISE WARNING '%',
        jsonb_build_object(
          'code', 'ENTITY_TYPE_REQUIRED',
          'class', 'internal',
          'context', context
        );
    END IF;
  ELSIF entity_type IS NOT NULL AND entity_id IS NULL THEN
    context := jsonb_build_object(
      'argument', 'entity_id',
      'claim', 'jwt.claims.entity_id',
      'entity_type', entity_type
    );
    IF strict_attribution THEN
      PERFORM errors.raise_error('ENTITY_ID_REQUIRED', context, 'internal');
    ELSE
      RAISE WARNING '%',
        jsonb_build_object(
          'code', 'ENTITY_ID_REQUIRED',
          'class', 'internal',
          'context', context
        );
    END IF;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE PARALLEL safe;