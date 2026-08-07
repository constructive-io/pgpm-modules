-- Verify schemas/object_store_utils/procedures/array_get_last  on pg

BEGIN;

SELECT assert_function('object_store_utils.array_get_last(anyarray)'::regprocedure);

ROLLBACK;
