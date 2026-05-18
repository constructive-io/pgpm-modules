-- Verify schemas/object_store_public/tables/object/indexes/frzn_idx  on pg

BEGIN;

SELECT verify_index ('object_store_public.object', 'frzn_idx');

ROLLBACK;
