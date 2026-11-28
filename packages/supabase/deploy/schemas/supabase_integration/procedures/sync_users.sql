-- Deploy schemas/supabase_integration/procedures/sync_users to pg

BEGIN;

CREATE FUNCTION supabase_integration.tg_sync_users()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
  EXECUTE format('INSERT INTO %s (id) VALUES ($1) ON CONFLICT (id) DO NOTHING',
                 TG_ARGV[0]::regclass) USING NEW.id;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION supabase_integration.tg_sync_users() FROM PUBLIC;

CREATE FUNCTION supabase_integration.sync_users(users_table regclass)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  target_table text;
BEGIN
  IF to_regclass('auth.users') IS NULL THEN
    RAISE EXCEPTION 'Cannot install Supabase user sync: auth.users does not exist';
  END IF;

  SELECT format('%I.%I', n.nspname, c.relname) INTO target_table
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.oid = users_table AND c.relkind IN ('r', 'p');

  IF target_table IS NULL THEN
    RAISE EXCEPTION 'Cannot install Supabase user sync: target users table % does not exist or is not a table',
      coalesce(users_table::text, '(null)');
  END IF;

  DROP TRIGGER IF EXISTS supabase_sync_users ON auth.users;
  EXECUTE format('CREATE TRIGGER supabase_sync_users AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION supabase_integration.tg_sync_users(%L)', target_table);
END;
$$;

REVOKE EXECUTE ON FUNCTION supabase_integration.sync_users(regclass) FROM PUBLIC;

COMMIT;
