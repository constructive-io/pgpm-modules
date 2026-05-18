-- Verify schemas/object_store_utils/procedures/array_pop  on pg

BEGIN;

SELECT verify_function ('object_store_utils.array_pop');

ROLLBACK;
