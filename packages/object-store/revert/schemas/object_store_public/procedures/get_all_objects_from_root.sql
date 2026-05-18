-- Revert schemas/object_store_public/procedures/get_all_objects_from_root from pg

BEGIN;

DROP FUNCTION object_store_public.get_all_objects_from_root;

COMMIT;
