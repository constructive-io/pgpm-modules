-- Deploy schemas/function_resolution/procedures/db_usage_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/db_usage_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- db_usage_module_registrations: the db_usage_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.db_usage_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    collect_db_table_stats_function text,
    collect_db_query_stats_function text,
    rollup_db_table_stats_usage_summary_function text,
    rollup_db_query_stats_usage_summary_function text,
    private_schema text
) AS $$
SELECT
    dum.database_id,
    (dum.database_id = app_scope.platform_database_id()) AS platform_owned,
    dum.collect_db_table_stats_function,
    dum.collect_db_query_stats_function,
    dum.rollup_db_table_stats_usage_summary_function,
    dum.rollup_db_query_stats_usage_summary_function,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.db_usage_module AS dum
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = dum.private_schema_id
WHERE dum.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.db_usage_module_registrations(uuid) FROM PUBLIC;

COMMIT;
