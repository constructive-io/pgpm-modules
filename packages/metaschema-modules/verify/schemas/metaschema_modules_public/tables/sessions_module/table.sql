-- Verify schemas/metaschema_modules_public/tables/sessions_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.sessions_module'::regclass);

ROLLBACK;
