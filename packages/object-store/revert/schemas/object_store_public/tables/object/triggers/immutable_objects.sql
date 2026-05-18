-- Revert schemas/object_store_public/tables/object/triggers/immutable_objects from pg

BEGIN;

DROP TRIGGER immutable_objects ON object_store_public.object;
DROP TRIGGER delete_immutable_objects ON object_store_public.object;
DROP FUNCTION object_store_private.tg_immutable_objects; 

COMMIT;
