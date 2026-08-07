-- Verify schemas/metaschema_modules_public/tables/denormalized_table_field/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.denormalized_table_field'::regclass);

ROLLBACK;
