-- Verify schemas/utils/procedures/throw  on pg

BEGIN;

SELECT assert_function('utils.throw()'::regprocedure);

ROLLBACK;
