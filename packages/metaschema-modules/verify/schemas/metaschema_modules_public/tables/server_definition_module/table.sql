-- Verify schemas/metaschema_modules_public/tables/server_definition_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.server_definition_module');

ROLLBACK;
