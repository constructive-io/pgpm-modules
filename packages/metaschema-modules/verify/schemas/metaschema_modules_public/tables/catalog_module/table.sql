-- Verify schemas/metaschema_modules_public/tables/catalog_module/table on pg

BEGIN;

SELECT id, database_id, scope, domains_table_id, apis_table_id, sites_table_id,
       images_table_id, images_table_name,
       redirects_table_id, redirects_table_name
FROM metaschema_modules_public.catalog_module
WHERE false;

ROLLBACK;
