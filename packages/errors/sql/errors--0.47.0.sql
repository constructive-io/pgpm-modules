\echo Use "CREATE EXTENSION errors" to load this file. \quit
CREATE SCHEMA errors;

GRANT USAGE ON SCHEMA errors TO PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA errors
  GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION errors.raise_error(
  code text,
  context jsonb DEFAULT '{}'::jsonb,
  error_class text DEFAULT 'internal'
) RETURNS void AS $EOFCODE$
BEGIN
  RAISE EXCEPTION USING
    ERRCODE = 'P0001',
    MESSAGE = code,
    DETAIL = jsonb_build_object(
      'code', code,
      'context', COALESCE(context, '{}'::jsonb),
      'class', error_class
    )::text;
END;
$EOFCODE$ LANGUAGE plpgsql;