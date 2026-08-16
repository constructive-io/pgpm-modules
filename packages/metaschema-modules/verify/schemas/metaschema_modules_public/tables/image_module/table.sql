-- Verify schemas/metaschema_modules_public/tables/image_module/table on pg

SELECT id, database_id, schema_id, private_schema_id,
       images_table_id, images_table_name,
       image_grants_table_id, image_grants_table_name,
       registries_table_id, registries_table_name,
       registry_grants_table_id, registry_grants_table_name,
       scope, prefix, entity_table_id, policies, provisions
FROM metaschema_modules_public.image_module
WHERE FALSE;
