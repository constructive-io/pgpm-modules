-- Verify schemas/function_resolution/procedures/service_principal on pg

BEGIN;

SELECT assert_function('function_resolution.service_principal(text)'::regprocedure);

ROLLBACK;
