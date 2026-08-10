-- Verify schemas/metaschema_modules_public/tables/data_capabilities_field/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.data_capabilities_field'::regclass);

ROLLBACK;
