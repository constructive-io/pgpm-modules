-- Revert schemas/object_store_utils/procedures/array_index_of from pg

BEGIN;

DROP FUNCTION object_store_utils.array_index_of;

COMMIT;
