-- Verify schemas/function_resolution/procedures/cluster_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.cluster_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
