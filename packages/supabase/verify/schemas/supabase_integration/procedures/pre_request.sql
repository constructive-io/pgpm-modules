-- Verify schemas/supabase_integration/procedures/pre_request from pg

BEGIN;

SELECT assert_function('supabase_integration.pre_request()'::regprocedure);

DO $$
BEGIN
  ASSERT EXISTS (
    SELECT FROM pg_proc,
      LATERAL aclexplode(coalesce(proacl, acldefault('f', proowner))) AS privilege
    WHERE oid = 'supabase_integration.pre_request()'::regprocedure
      AND privilege.grantee = 0 AND privilege.privilege_type = 'EXECUTE'
  );
  ASSERT NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'supabase_integration.pre_request()'::regprocedure);
END;
$$;

ROLLBACK;
