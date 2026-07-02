-- Verify schemas/metaschema_modules_public/tables/server_deployment_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.server_deployment_module');

ROLLBACK;
