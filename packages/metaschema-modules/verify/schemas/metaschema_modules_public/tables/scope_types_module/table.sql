-- Verify schemas/metaschema_modules_public/tables/scope_types_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.scope_types_module'::regclass);

ROLLBACK;
