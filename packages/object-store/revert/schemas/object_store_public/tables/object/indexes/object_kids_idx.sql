-- Revert schemas/object_store_public/tables/object/indexes/object_kids_idx from pg

BEGIN;

DROP INDEX object_store_public.object_kids_idx;

COMMIT;
