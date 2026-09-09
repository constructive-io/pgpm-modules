-- Verify schemas/utils/procedures/default_self_reference  on pg

BEGIN;

SELECT assert_function('utils.default_self_reference()'::regprocedure);

ROLLBACK;
