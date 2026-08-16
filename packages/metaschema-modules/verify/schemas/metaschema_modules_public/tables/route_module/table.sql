-- Verify schemas/metaschema_modules_public/tables/route_module/table on pg

BEGIN;

SELECT id, database_id, scope, routes_table_id,
       redirects_table_id, redirects_table_name
FROM metaschema_modules_public.route_module
WHERE false;

ROLLBACK;
