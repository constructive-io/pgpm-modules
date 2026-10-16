-- Verify schemas/function_resolution/procedures/tenant_auth_entry  on pg

BEGIN;

SELECT assert_function('function_resolution.tenant_auth_entry(uuid)'::regprocedure);

ROLLBACK;
