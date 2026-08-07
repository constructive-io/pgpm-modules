-- Verify schemas/object_store_public/tables/object/table on pg

BEGIN;

SELECT assert_table('object_store_public.object'::regclass);

ROLLBACK;
