-- Revert schemas/supabase_integration/procedures/sync_users from pg

BEGIN;

DROP FUNCTION supabase_integration.sync_users(regclass);

DO $$
BEGIN
  IF to_regclass('auth.users') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS supabase_sync_users ON auth.users;
  END IF;
END;
$$;

DROP FUNCTION supabase_integration.tg_sync_users();

COMMIT;
