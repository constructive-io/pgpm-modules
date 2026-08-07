-- Verify schemas/ctx/procedures/ip_address  on pg

BEGIN;

SELECT assert_function('ctx.ip_address()'::regprocedure);

ROLLBACK;

