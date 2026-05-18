-- Verify schemas/object_store_utils/procedures/array_index_of  on pg

BEGIN;

SELECT verify_function ('object_store_utils.array_index_of');

ROLLBACK;
