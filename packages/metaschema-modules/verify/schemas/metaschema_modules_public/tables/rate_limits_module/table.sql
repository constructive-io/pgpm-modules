-- Verify schemas/metaschema_modules_public/tables/rate_limits_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.rate_limits_module'::regclass);

ROLLBACK;
