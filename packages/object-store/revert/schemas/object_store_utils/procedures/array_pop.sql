-- Revert schemas/object_store_utils/procedures/array_pop from pg

BEGIN;

DROP FUNCTION object_store_utils.array_pop(anyarray);

COMMIT;
