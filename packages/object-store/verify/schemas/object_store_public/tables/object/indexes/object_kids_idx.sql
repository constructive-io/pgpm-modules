-- Verify schemas/object_store_public/tables/object/indexes/object_kids_idx  on pg

BEGIN;

SELECT verify_index ('object_store_public.object', 'object_kids_idx');

ROLLBACK;
