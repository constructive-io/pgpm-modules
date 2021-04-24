-- Revert schemas/meta_public/tables/denormalized_fields_tables/table from pg

BEGIN;

DROP TABLE meta_public.denormalized_fields_tables;

COMMIT;
