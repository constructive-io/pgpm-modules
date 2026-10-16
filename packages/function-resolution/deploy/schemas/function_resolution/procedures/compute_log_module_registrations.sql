-- Deploy schemas/function_resolution/procedures/compute_log_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/compute_log_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/field/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- compute_log_module_registrations: the compute_log_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.compute_log_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    compute_log_table_name text,
    usage_summary_table_name text,
    rollup_function_name text,
    logs_per_database boolean,
    entity_field text,
    public_schema text,
    private_schema text
) AS $$
SELECT
    clm.database_id,
    (clm.database_id = app_scope.platform_database_id()) AS platform_owned,
    clm.scope,
    clm.compute_log_table_name,
    clm.usage_summary_table_name,
    clm.rollup_function_name,
    EXISTS (SELECT 1 FROM metaschema_public.field AS f WHERE f.table_id = clm.compute_log_table_id AND f.name = 'database_id') AS logs_per_database,
    clm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.compute_log_module AS clm
    LEFT JOIN metaschema_public.schema ps ON ps.id = clm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = clm.private_schema_id
WHERE clm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.compute_log_module_registrations(uuid) FROM PUBLIC;

COMMIT;
