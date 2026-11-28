-- Verify schemas/supabase_integration/procedures/sync_users from pg

BEGIN;

SELECT assert_function('supabase_integration.sync_users(regclass)'::regprocedure);
SELECT assert_function('supabase_integration.tg_sync_users()'::regprocedure);

DO $$
BEGIN
  ASSERT NOT EXISTS (
    SELECT FROM pg_proc,
      LATERAL aclexplode(coalesce(proacl, acldefault('f', proowner))) AS privilege
    WHERE oid IN ('supabase_integration.sync_users(regclass)'::regprocedure,
                  'supabase_integration.tg_sync_users()'::regprocedure)
      AND privilege.grantee = 0 AND privilege.privilege_type = 'EXECUTE'
  );
  ASSERT (SELECT prosecdef FROM pg_proc WHERE oid = 'supabase_integration.tg_sync_users()'::regprocedure);
END;
$$;

ROLLBACK;
