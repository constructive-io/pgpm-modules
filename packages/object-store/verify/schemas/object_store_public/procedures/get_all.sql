-- Verify schemas/object_store_public/procedures/get_all  on pg

BEGIN;

SELECT assert_function('object_store_public.get_all(uuid, uuid)'::regprocedure);

ROLLBACK;
