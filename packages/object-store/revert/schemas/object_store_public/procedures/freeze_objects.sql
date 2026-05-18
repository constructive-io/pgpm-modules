-- Revert schemas/object_store_public/procedures/freeze_objects from pg

BEGIN;

DROP FUNCTION object_store_public.freeze_objects;

COMMIT;
