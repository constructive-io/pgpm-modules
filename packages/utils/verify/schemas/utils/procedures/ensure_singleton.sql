-- Verify schemas/utils/procedures/ensure_singleton  on pg

BEGIN;

SELECT assert_function('utils.ensure_singleton()'::regprocedure);

ROLLBACK;
