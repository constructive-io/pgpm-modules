-- Verify schemas/ltree_helpers/procedures/to_query on pg

BEGIN;

SELECT assert_function('ltree_helpers.to_query(text)'::regprocedure);

ROLLBACK;
