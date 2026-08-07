-- Verify schemas/metaschema_modules_public/tables/invites_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.invites_module'::regclass);

ROLLBACK;
