-- Verify schemas/function_resolution/procedures/infra_secrets_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.infra_secrets_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
