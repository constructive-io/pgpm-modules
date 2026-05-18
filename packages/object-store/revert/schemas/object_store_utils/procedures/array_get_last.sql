-- Revert schemas/object_store_utils/procedures/array_get_last from pg

BEGIN;

DROP FUNCTION object_store_utils.array_get_last;

COMMIT;
