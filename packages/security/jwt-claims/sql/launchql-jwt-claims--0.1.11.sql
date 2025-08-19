\echo Use "CREATE EXTENSION launchql-jwt-claims" to load this file. \quit
CREATE SCHEMA jwt_public;

GRANT USAGE ON SCHEMA jwt_public TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA jwt_public 
 GRANT EXECUTE ON FUNCTIONS  TO authenticated;

CREATE SCHEMA jwt_private;

GRANT USAGE ON SCHEMA jwt_private TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA jwt_private 
 GRANT EXECUTE ON FUNCTIONS  TO authenticated;

CREATE FUNCTION jwt_public.current_user_id (  ) RETURNS uuid AS $EOFCODE$
DECLARE
  v_identifier_id uuid;
BEGIN
  IF current_setting('jwt.claims.user_id', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_identifier_id = current_setting('jwt.claims.user_id', TRUE)::uuid;
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UUID value';
    RETURN NULL;
    END;
    RETURN v_identifier_id;
  ELSE
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION jwt_public.current_ip_address (  ) RETURNS inet AS $EOFCODE$
DECLARE
  v_ip_addr inet;
BEGIN
  IF current_setting('jwt.claims.ip_address', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_ip_addr = trim(current_setting('jwt.claims.ip_address', TRUE))::inet;
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid IP';
    RETURN NULL;
    END;
    RETURN v_ip_addr;
  ELSE
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION jwt_public.current_user_agent (  ) RETURNS text AS $EOFCODE$
DECLARE
  v_uagent text;
BEGIN
  IF current_setting('jwt.claims.user_agent', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_uagent = current_setting('jwt.claims.user_agent', TRUE);
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UserAgent';
    RETURN NULL;
    END;
    RETURN v_uagent;
  ELSE
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION jwt_private.current_database_id (  ) RETURNS uuid AS $EOFCODE$
DECLARE
  v_identifier_id uuid;
BEGIN
  IF current_setting('jwt.claims.database_id', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_identifier_id = current_setting('jwt.claims.database_id', TRUE)::uuid;
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UUID value';
    RETURN NULL;
    END;
    RETURN v_identifier_id;
  ELSE
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION jwt_public.current_group_ids (  ) RETURNS uuid[] AS $EOFCODE$
DECLARE
  v_identifier_ids uuid[];
BEGIN
  IF current_setting('jwt.claims.group_ids', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_identifier_ids = current_setting('jwt.claims.group_ids', TRUE)::uuid[];
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UUID value';
    RETURN ARRAY[]::uuid[];
    END;
    RETURN v_identifier_ids;
  ELSE
    RETURN ARRAY[]::uuid[];
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;