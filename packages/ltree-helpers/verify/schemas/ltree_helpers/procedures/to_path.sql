-- Verify schemas/ltree_helpers/procedures/to_path on pg

BEGIN;

SELECT assert_function('ltree_helpers.to_path(text)'::regprocedure);

ROLLBACK;
