-- Verify schemas/supabase_integration/schema from pg

BEGIN;

SELECT assert_schema('supabase_integration'::regnamespace);

DO $$
BEGIN
  ASSERT has_schema_privilege('anon', 'supabase_integration', 'USAGE');
  ASSERT has_schema_privilege('authenticated', 'supabase_integration', 'USAGE');
END;
$$;

ROLLBACK;
