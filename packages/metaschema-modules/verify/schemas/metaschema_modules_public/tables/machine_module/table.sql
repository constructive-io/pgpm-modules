-- Verify schemas/metaschema_modules_public/tables/machine_module/table on pg

SELECT id, database_id, schema_id, private_schema_id,
       machines_table_id, machines_table_name,
       machine_sessions_table_id, machine_sessions_table_name,
       machine_messages_table_id, machine_messages_table_name,
       partition_interval, retention, premake,
       scope, prefix, entity_table_id, policies, provisions
FROM metaschema_modules_public.machine_module
WHERE FALSE;
