-- Revert schemas/object_store_public/tables/object/indexes/frzn_idx from pg

BEGIN;

DROP INDEX object_store_public.frzn_idx;

COMMIT;
