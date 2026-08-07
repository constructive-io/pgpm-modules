-- Verify schemas/metaschema_modules_public/tables/memberships_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.memberships_module'::regclass);

ROLLBACK;
