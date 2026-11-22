-- Verify schemas/supabase_integration/schema from pg

BEGIN;

SELECT assert_schema('supabase_integration'::regnamespace);

DO $$
BEGIN
  ASSERT EXISTS (
    SELECT FROM pg_namespace,
      LATERAL aclexplode(nspacl) AS privilege
    WHERE nspname = 'supabase_integration'
      AND privilege.grantee = 0 AND privilege.privilege_type = 'USAGE'
  );
END;
$$;

ROLLBACK;
