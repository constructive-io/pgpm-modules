-- Deploy schemas/function_resolution/procedures/billing_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/billing_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- billing_module_registrations: the billing_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.billing_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    public_schema text,
    private_schema text,
    record_usage_function text,
    meters_table_name text,
    grant_meter_credits_function text,
    credit_packs_table_name text,
    sweep_expired_subscriptions_function text,
    rollup_usage_summary_function text
) AS $$
SELECT
    bm.database_id,
    (bm.database_id = app_scope.platform_database_id()) AS platform_owned,
    'app'::text AS scope,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    bm.record_usage_function,
    bm.meters_table_name,
    bm.grant_meter_credits_function,
    bm.credit_packs_table_name,
    bm.sweep_expired_subscriptions_function,
    bm.rollup_usage_summary_function
FROM metaschema_modules_public.billing_module AS bm
    LEFT JOIN metaschema_public.schema ps ON ps.id = bm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = bm.private_schema_id
WHERE bm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.billing_module_registrations(uuid) FROM PUBLIC;

COMMIT;
