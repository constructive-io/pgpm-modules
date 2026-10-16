-- Verify schemas/function_resolution/procedures/request_protection  on pg

BEGIN;

SELECT assert_function('function_resolution.request_protection(uuid, uuid)'::regprocedure);

ROLLBACK;
