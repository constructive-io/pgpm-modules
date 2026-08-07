-- Verify schemas/ctx/procedures/uagent on pg

BEGIN;

SELECT assert_function('ctx.uagent()'::regprocedure);

ROLLBACK;

