-- Verify schemas/object_store_public/procedures/get_path_objects_from_root  on pg

BEGIN;

SELECT assert_function('object_store_public.get_path_objects_from_root(uuid, uuid, text[])'::regprocedure);

ROLLBACK;
