\echo Use "CREATE EXTENSION pgpm-supabase" to load this file. \quit
CREATE SCHEMA supabase_integration;

GRANT USAGE ON SCHEMA supabase_integration TO anon, authenticated;

DO $EOFCODE$
BEGIN
  IF current_setting('server_version_num')::integer >= 160000 THEN
    GRANT anonymous TO anon WITH INHERIT FALSE, SET TRUE;
  ELSE
    GRANT anonymous TO anon;
  END IF;
END;
$EOFCODE$;

CREATE FUNCTION supabase_integration.pre_request() RETURNS void LANGUAGE plpgsql AS $EOFCODE$
DECLARE
  subject text;
BEGIN
  IF current_user = 'anon' THEN
    PERFORM set_config('role', 'anonymous', true);
  ELSIF current_user = 'authenticated' THEN
    subject := nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub';
    IF subject IS NOT NULL AND subject <> '' THEN
      PERFORM set_config('jwt.claims.user_id', subject, true);
      PERFORM set_config('jwt.claims.principal_id', subject, true);
    END IF;
  END IF;
END;
$EOFCODE$;

REVOKE ALL ON FUNCTION supabase_integration.pre_request() FROM PUBLIC RESTRICT;

GRANT EXECUTE ON FUNCTION supabase_integration.pre_request() TO anon, authenticated;