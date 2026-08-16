-- Verify schemas/metaschema_modules_public/tables/repository_module/table on pg

SELECT id, database_id, schema_id, private_schema_id,
       repositories_table_id, repositories_table_name,
       repository_events_table_id, repository_events_table_name,
       workflows_table_id, workflows_table_name,
       builds_table_id, builds_table_name,
       build_steps_table_id, build_steps_table_name,
       proposals_table_id, proposals_table_name,
       proposal_comments_table_id, proposal_comments_table_name,
       proposal_reactions_table_id, proposal_reactions_table_name,
       has_builds, search, scope, prefix, entity_table_id, policies, provisions
FROM metaschema_modules_public.repository_module
WHERE FALSE;
