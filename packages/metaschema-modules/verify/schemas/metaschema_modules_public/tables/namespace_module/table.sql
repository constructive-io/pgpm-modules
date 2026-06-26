-- Verify schemas/metaschema_modules_public/tables/namespace_module/table on pg

BEGIN;

SELECT id, database_id, schema_id, private_schema_id,
       public_schema_name, private_schema_name,
       namespaces_table_id, namespace_events_table_id,
       namespaces_table_name, namespace_events_table_name,
       api_name, private_api_name, scope, prefix,
       entity_table_id, policies, provisions, default_permissions
FROM metaschema_modules_public.namespace_module
WHERE false;

ROLLBACK;
