-- Revert schemas/object_store_utils/procedures/array_shift from pg

BEGIN;

DROP FUNCTION object_store_utils.array_shift(anyarray);

COMMIT;
