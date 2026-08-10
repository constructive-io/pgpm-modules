-- Verify schemas/metaschema_modules_public/tables/file_ref_field/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.file_ref_field'::regclass);

ROLLBACK;
