-- Verify schemas/supabase_integration/procedures/pre_request from pg

BEGIN;

SELECT assert_function('supabase_integration.pre_request()'::regprocedure);

DO $$
BEGIN
  ASSERT has_function_privilege('anon', 'supabase_integration.pre_request()', 'EXECUTE');
  ASSERT has_function_privilege('authenticated', 'supabase_integration.pre_request()', 'EXECUTE');
  ASSERT NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'supabase_integration.pre_request()'::regprocedure);
END;
$$;

ROLLBACK;
