-- Deploy schemas/function_resolution/procedures/graph_execution_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/graph_execution_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- graph_execution_module_registrations: the graph_execution_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.graph_execution_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    prefix text,
    node_states_table_name text,
    executions_table_name text,
    outputs_table_name text,
    public_schema text,
    private_schema text
) AS $$
SELECT
    gem.database_id,
    (gem.database_id = app_scope.platform_database_id()) AS platform_owned,
    gem.scope,
    gem.prefix,
    node_states_t.name AS node_states_table_name,
    executions_t.name AS executions_table_name,
    outputs_t.name AS outputs_table_name,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.graph_execution_module AS gem
    LEFT JOIN metaschema_public.schema ps ON ps.id = gem.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = gem.private_schema_id
    LEFT JOIN metaschema_public.table node_states_t ON node_states_t.id = gem.node_states_table_id
    LEFT JOIN metaschema_public.table executions_t ON executions_t.id = gem.executions_table_id
    LEFT JOIN metaschema_public.table outputs_t ON outputs_t.id = gem.outputs_table_id
WHERE ($1 IS NULL OR gem.database_id = $1)
  AND ($2 IS NULL OR gem.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.graph_execution_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
