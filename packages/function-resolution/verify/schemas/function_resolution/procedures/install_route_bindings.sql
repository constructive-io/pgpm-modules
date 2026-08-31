-- Verify schemas/function_resolution/procedures/install_route_bindings on pg

BEGIN;

SELECT assert_function('function_resolution.install_route_bindings(uuid, text, text, uuid, jsonb, uuid)'::regprocedure);

ROLLBACK;
