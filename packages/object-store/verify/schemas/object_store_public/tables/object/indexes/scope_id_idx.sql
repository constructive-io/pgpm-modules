-- Verify schemas/object_store_public/tables/object/indexes/scope_id_idx  on pg

BEGIN;

SELECT verify_index ('object_store_public.object', 'scope_id_idx');

ROLLBACK;
