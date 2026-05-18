-- Revert schemas/object_store_public/tables/object/indexes/scope_id_idx from pg

BEGIN;

DROP INDEX object_store_public.scope_id_idx;

COMMIT;
