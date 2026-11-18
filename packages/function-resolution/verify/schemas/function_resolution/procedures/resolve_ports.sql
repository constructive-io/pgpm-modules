-- Verify schemas/function_resolution/procedures/resolve_ports  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_ports(uuid, text, uuid, text)'::regprocedure);

ROLLBACK;
