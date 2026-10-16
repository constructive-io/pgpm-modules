-- Deploy schemas/function_resolution/procedures/function_deployment_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/function_deployment_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- function_deployment_module_registrations: the function_deployment_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.function_deployment_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    deployments_table_name text,
    deployment_events_table_name text,
    public_schema text,
    private_schema text
) AS $$
SELECT
    fdm.database_id,
    (fdm.database_id = app_scope.platform_database_id()) AS platform_owned,
    fdm.scope,
    fdm.entity_field,
    fdm.deployments_table_name,
    fdm.deployment_events_table_name,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.function_deployment_module AS fdm
    LEFT JOIN metaschema_public.schema ps ON ps.id = fdm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = fdm.private_schema_id
WHERE ($1 IS NULL OR fdm.database_id = $1)
  AND ($2 IS NULL OR fdm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.function_deployment_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
