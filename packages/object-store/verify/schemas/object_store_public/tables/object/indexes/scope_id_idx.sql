-- Verify schemas/object_store_public/tables/object/indexes/scope_id_idx  on pg

BEGIN;

SELECT assert_index('object_store_public.scope_id_idx'::regclass, 'object_store_public.object'::regclass);

ROLLBACK;
