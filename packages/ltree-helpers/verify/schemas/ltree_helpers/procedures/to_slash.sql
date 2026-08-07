-- Verify schemas/ltree_helpers/procedures/to_slash on pg

BEGIN;

SELECT assert_function('ltree_helpers.to_slash(ltree)'::regprocedure);

ROLLBACK;
