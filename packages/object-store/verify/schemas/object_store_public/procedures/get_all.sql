-- Verify schemas/object_store_public/procedures/get_all  on pg

BEGIN;

SELECT verify_function ('object_store_public.get_all');

ROLLBACK;
