-- Verify schemas/object_store_public/tables/object/indexes/object_kids_idx  on pg

BEGIN;

SELECT assert_index('object_store_public.object_kids_idx'::regclass, 'object_store_public.object'::regclass);

ROLLBACK;
