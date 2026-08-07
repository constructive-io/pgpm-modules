-- Verify schemas/object_store_public/tables/object/triggers/immutable_objects  on pg

BEGIN;

SELECT assert_function('object_store_private.tg_immutable_objects()'::regprocedure);
SELECT assert_trigger('object_store_public.object'::regclass, 'immutable_objects', 'object_store_private.tg_immutable_objects'::regproc, 19);
SELECT assert_trigger('object_store_public.object'::regclass, 'delete_immutable_objects', 'object_store_private.tg_immutable_objects'::regproc, 11);

ROLLBACK;
