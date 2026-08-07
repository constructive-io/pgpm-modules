-- Verify schemas/object_store_public/tables/object/indexes/frzn_idx  on pg

BEGIN;

SELECT assert_index('object_store_public.frzn_idx'::regclass, 'object_store_public.object'::regclass);

ROLLBACK;
