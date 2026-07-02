-- Verify schemas/metaschema_modules_public/tables/route_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.route_module');

ROLLBACK;
