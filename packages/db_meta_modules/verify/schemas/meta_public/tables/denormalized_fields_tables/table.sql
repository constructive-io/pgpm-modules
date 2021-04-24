-- Verify schemas/meta_public/tables/denormalized_fields_tables/table on pg

BEGIN;

SELECT verify_table ('meta_public.denormalized_fields_tables');

ROLLBACK;
