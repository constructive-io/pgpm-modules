-- Verify schemas/function_resolution/procedures/graph_execution_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.graph_execution_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
