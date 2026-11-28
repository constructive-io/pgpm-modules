\echo Use "CREATE EXTENSION pgpm-supabase" to load this file. \quit
CREATE SCHEMA supabase_integration;

GRANT USAGE ON SCHEMA supabase_integration TO PUBLIC;

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

GRANT EXECUTE ON FUNCTION supabase_integration.pre_request() TO PUBLIC;

CREATE FUNCTION supabase_integration.tg_sync_users() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog, pg_temp AS $EOFCODE$
BEGIN
  EXECUTE format('INSERT INTO %s (id) VALUES ($1) ON CONFLICT (id) DO NOTHING',
                 TG_ARGV[0]::oid::regclass) USING NEW.id;
  RETURN NEW;
END;
$EOFCODE$;

REVOKE EXECUTE ON FUNCTION supabase_integration.tg_sync_users() FROM PUBLIC RESTRICT;

CREATE FUNCTION supabase_integration.sync_users(
  users_table regclass
) RETURNS void LANGUAGE plpgsql SET search_path TO pg_catalog, pg_temp AS $EOFCODE$
BEGIN
  IF to_regclass('auth.users') IS NULL THEN
    RAISE EXCEPTION 'Cannot install Supabase user sync: auth.users does not exist';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_class WHERE oid = users_table AND relkind IN ('r', 'p')) THEN
    RAISE EXCEPTION 'Cannot install Supabase user sync: target users table % does not exist or is not a table',
      coalesce(users_table::text, '(null)');
  END IF;

  DROP TRIGGER IF EXISTS supabase_sync_users ON auth.users;
  EXECUTE format('CREATE TRIGGER supabase_sync_users AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION supabase_integration.tg_sync_users(%L)', users_table::oid);
END;
$EOFCODE$;

REVOKE EXECUTE ON FUNCTION supabase_integration.sync_users(regclass) FROM PUBLIC RESTRICT;