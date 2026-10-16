-- Verify schemas/function_resolution/procedures/agent_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.agent_module_registrations(uuid)'::regprocedure);

ROLLBACK;
