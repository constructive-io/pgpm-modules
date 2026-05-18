-- Verify schemas/object_store_utils/procedures/array_shift  on pg

BEGIN;

SELECT verify_function ('object_store_utils.array_shift');

ROLLBACK;
