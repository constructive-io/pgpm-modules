-- Deploy schemas/supabase_integration/procedures/pre_request to pg

BEGIN;

CREATE FUNCTION supabase_integration.pre_request()
RETURNS void
LANGUAGE plpgsql
AS $$
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
$$;

COMMIT;
