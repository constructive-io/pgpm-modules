-- Verify schemas/object_store_public/tables/object/triggers/immutable_objects  on pg

BEGIN;

SELECT verify_function ('object_store_private.tg_immutable_objects'); 
SELECT verify_trigger ('object_store_public.immutable_objects');
SELECT verify_trigger ('object_store_public.delete_immutable_objects');

ROLLBACK;
