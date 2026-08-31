-- Verify schemas/function_resolution/procedures/install_mantra on pg

BEGIN;

SELECT assert_function('function_resolution.install_mantra(uuid, regclass, uuid, jsonb, uuid)'::regprocedure);

ROLLBACK;
