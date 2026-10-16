-- Deploy schemas/function_resolution/procedures/resource_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/resource_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- resource_module_registrations: the resource_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.resource_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    resources_table_name text,
    resource_definitions_table_name text,
    resource_installations_table_name text,
    prefix text,
    resource_events_table_name text,
    resource_status_checks_table_name text,
    resource_usage_log_table_name text,
    resource_usage_summary_table_name text,
    resolved_requirements_view_name text,
    requirements_state_view_name text,
    entity_field text,
    public_schema text,
    private_schema text,
    registry_bindings_table_name text,
    builder_bindings_table_name text,
    rollup_resource_usage_summary_function text,
    resource_billing_rollup_function text
) AS $$
SELECT
    rm.database_id,
    (rm.database_id = app_scope.platform_database_id()) AS platform_owned,
    rm.scope,
    rm.resources_table_name,
    rm.resource_definitions_table_name,
    rm.resource_installations_table_name,
    rm.prefix,
    rm.resource_events_table_name,
    rm.resource_status_checks_table_name,
    rm.resource_usage_log_table_name,
    rm.resource_usage_summary_table_name,
    rm.resolved_requirements_view_name,
    rm.requirements_state_view_name,
    rm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    rm.registry_bindings_table_name,
    rm.builder_bindings_table_name,
    rm.rollup_resource_usage_summary_function,
    rm.resource_billing_rollup_function
FROM metaschema_modules_public.resource_module AS rm
    LEFT JOIN metaschema_public.schema ps ON ps.id = rm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = rm.private_schema_id
WHERE ($1 IS NULL OR rm.database_id = $1)
  AND ($2 IS NULL OR rm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.resource_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
