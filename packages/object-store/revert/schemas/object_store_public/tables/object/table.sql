-- Revert schemas/object_store_public/tables/object/table from pg

BEGIN;

DROP TABLE object_store_public.object;

COMMIT;
