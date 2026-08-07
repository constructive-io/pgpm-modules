-- Verify schemas/ctx/procedures/origin  on pg

BEGIN;

SELECT assert_function('ctx.origin()'::regprocedure);

ROLLBACK;

