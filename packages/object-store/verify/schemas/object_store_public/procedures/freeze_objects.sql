-- Verify schemas/object_store_public/procedures/freeze_objects  on pg

BEGIN;

SELECT assert_function('object_store_public.freeze_objects(uuid, uuid)'::regprocedure);

ROLLBACK;
