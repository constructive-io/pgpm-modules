-- Deploy schemas/function_resolution/procedures/cluster_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/cluster_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- cluster_module_registrations: the cluster_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.cluster_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    prefix text,
    host_database_id uuid,
    public_schema text,
    private_schema text,
    clusters_table_name text,
    cluster_events_table_name text,
    database_servers_table_name text,
    physical_databases_table_name text,
    database_placements_table_name text
) AS $$
SELECT
    cm.database_id,
    (cm.database_id = app_scope.platform_database_id()) AS platform_owned,
    cm.scope,
    cm.entity_field,
    cm.prefix,
    cm.database_id AS host_database_id,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    clusters_t.name AS clusters_table_name,
    events_t.name AS cluster_events_table_name,
    servers_t.name AS database_servers_table_name,
    pdbs_t.name AS physical_databases_table_name,
    placements_t.name AS database_placements_table_name
FROM metaschema_modules_public.cluster_module AS cm
    LEFT JOIN metaschema_public.schema ps ON ps.id = cm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = cm.private_schema_id
    LEFT JOIN metaschema_public.table clusters_t
    ON clusters_t.id = cm.clusters_table_id AND cm.clusters_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table events_t
    ON events_t.id = cm.cluster_events_table_id AND cm.cluster_events_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table servers_t
    ON servers_t.id = cm.database_servers_table_id AND cm.database_servers_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table pdbs_t
    ON pdbs_t.id = cm.physical_databases_table_id AND cm.physical_databases_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table placements_t
    ON placements_t.id = cm.database_placements_table_id AND cm.database_placements_table_id <> uuid_nil()
WHERE ($1 IS NULL OR cm.database_id = $1)
  AND ($2 IS NULL OR cm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.cluster_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
