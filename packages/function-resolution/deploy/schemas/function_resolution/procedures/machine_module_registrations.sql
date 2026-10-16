-- Deploy schemas/function_resolution/procedures/machine_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/machine_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- machine_module_registrations: the machine_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.machine_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    prefix text,
    entity_field text,
    machines_table_name text,
    machine_sessions_table_name text,
    machine_messages_table_name text,
    partition_interval text,
    retention text,
    premake integer,
    public_schema text,
    private_schema text
) AS $$
SELECT
    mm.database_id,
    (mm.database_id = app_scope.platform_database_id()) AS platform_owned,
    mm.scope,
    mm.prefix,
    mm.entity_field,
    mm.machines_table_name,
    mm.machine_sessions_table_name,
    mm.machine_messages_table_name,
    mm.partition_interval,
    mm.retention,
    mm.premake,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.machine_module AS mm
    LEFT JOIN metaschema_public.schema ps ON ps.id = mm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = mm.private_schema_id
WHERE ($1 IS NULL OR mm.database_id = $1)
  AND ($2 IS NULL OR mm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.machine_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
