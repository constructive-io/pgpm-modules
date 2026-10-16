-- Deploy schemas/function_resolution/procedures/agent_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/agent_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- agent_module_registrations: the agent_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.agent_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    has_plans boolean,
    has_agents boolean,
    has_runs boolean,
    public_schema text,
    private_schema text,
    thread_table_name text,
    message_table_name text,
    task_table_name text,
    plan_table_name text,
    agent_table_name text,
    persona_table_name text,
    resource_table_name text,
    run_table_name text,
    event_table_name text,
    workspace_table_name text,
    settle_run_cost_function_name text
) AS $$
SELECT
    am.database_id,
    (am.database_id = app_scope.platform_database_id()) AS platform_owned,
    am.scope,
    am.entity_field,
    am.has_plans,
    am.has_agents,
    am.has_runs,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    thread_t.name AS thread_table_name,
    message_t.name AS message_table_name,
    task_t.name AS task_table_name,
    plan_t.name AS plan_table_name,
    agent_t.name AS agent_table_name,
    persona_t.name AS persona_table_name,
    resource_t.name AS resource_table_name,
    run_t.name AS run_table_name,
    event_t.name AS event_table_name,
    workspace_t.name AS workspace_table_name,
    am.settle_run_cost_function_name
FROM metaschema_modules_public.agent_module AS am
    LEFT JOIN metaschema_public.schema ps ON ps.id = am.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = am.private_schema_id
    LEFT JOIN metaschema_public.table thread_t
    ON thread_t.id = am.thread_table_id AND am.thread_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table message_t
    ON message_t.id = am.message_table_id AND am.message_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table task_t
    ON task_t.id = am.task_table_id AND am.task_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table plan_t
    ON plan_t.id = am.plan_table_id
    LEFT JOIN metaschema_public.table agent_t
    ON agent_t.id = am.agent_table_id
    LEFT JOIN metaschema_public.table persona_t
    ON persona_t.id = am.persona_table_id
    LEFT JOIN metaschema_public.table resource_t
    ON resource_t.id = am.resource_table_id
    LEFT JOIN metaschema_public.table run_t
    ON run_t.id = am.run_table_id
    LEFT JOIN metaschema_public.table event_t
    ON event_t.id = am.event_table_id
    LEFT JOIN metaschema_public.table workspace_t
    ON workspace_t.id = am.workspace_table_id
WHERE am.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.agent_module_registrations(uuid) FROM PUBLIC;

COMMIT;
