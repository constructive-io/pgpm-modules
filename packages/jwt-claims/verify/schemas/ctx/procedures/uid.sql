-- Verify schemas/ctx/procedures/uid on pg

BEGIN;

SELECT assert_function('ctx.uid()'::regprocedure);

ROLLBACK;

