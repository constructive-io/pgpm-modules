-- Deploy schemas/function_resolution/procedures/refusal_log_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/refusal_log_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- refusal_log_module_registrations: the refusal_log_module rows the platform login reads (worker
-- sql-runner for refusal_usage:rollup_summary). A NOBYPASSRLS login sees none of these rows
-- directly, so this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.refusal_log_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    log_table_name text,
    summary_table_name text,
    record_refusals_function text,
    rollup_refusal_usage_summary_function text,
    entity_field text,
    public_schema text,
    private_schema text
) AS $$
SELECT
    rlm.database_id,
    (rlm.database_id = app_scope.platform_database_id()) AS platform_owned,
    rlm.scope,
    rlm.log_table_name,
    rlm.summary_table_name,
    rlm.record_refusals_function,
    rlm.rollup_refusal_usage_summary_function,
    rlm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.refusal_log_module AS rlm
    LEFT JOIN metaschema_public.schema ps ON ps.id = rlm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = rlm.private_schema_id
WHERE rlm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.refusal_log_module_registrations(uuid) FROM PUBLIC;

COMMIT;
