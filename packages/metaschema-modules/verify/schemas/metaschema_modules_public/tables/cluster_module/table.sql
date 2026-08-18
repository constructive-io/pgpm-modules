-- Verify schemas/metaschema_modules_public/tables/cluster_module/table on pg

SELECT id, database_id, entity_field, schema_id, private_schema_id,
       public_schema_name, private_schema_name,
       clusters_table_id, clusters_table_name,
       cluster_events_table_id, cluster_events_table_name,
       database_servers_table_id, database_servers_table_name,
       physical_databases_table_id, physical_databases_table_name,
       database_placements_table_id, database_placements_table_name,
       api_name, private_api_name,
       partition_interval, retention, premake,
       scope, prefix, policies, provisions, default_capabilities
FROM metaschema_modules_public.cluster_module
WHERE FALSE;
