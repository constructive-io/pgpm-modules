-- Verify schemas/function_resolution/procedures/oauth_requests_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.oauth_requests_module_registrations(uuid)'::regprocedure);

ROLLBACK;
