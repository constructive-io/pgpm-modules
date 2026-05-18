-- Verify schemas/object_store_public/tables/object/table on pg

BEGIN;

SELECT verify_table ('object_store_public.object');

ROLLBACK;
