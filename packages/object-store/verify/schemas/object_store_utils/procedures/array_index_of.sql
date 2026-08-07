-- Verify schemas/object_store_utils/procedures/array_index_of  on pg

BEGIN;

SELECT assert_function('object_store_utils.array_index_of(anyarray, anyelement)'::regprocedure);

ROLLBACK;
