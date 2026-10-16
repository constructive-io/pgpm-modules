-- Deploy schemas/function_resolution/procedures/webhook_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/infra_secrets_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/namespace_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/webhook_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- webhook_module_registrations: the webhook_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.webhook_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    webhook_endpoints_table_name text,
    webhook_events_table_name text,
    entity_field text,
    public_schema text,
    private_schema text,
    signing_secrets_prefix text,
    signing_secrets_entity_field text,
    signing_secrets_schema text,
    namespaces_table_name text,
    namespaces_entity_field text,
    namespaces_schema text,
    function_invocation_module_id uuid
) AS $$
SELECT
    wm.database_id,
    (wm.database_id = app_scope.platform_database_id()) AS platform_owned,
    wm.scope,
    wm.webhook_endpoints_table_name,
    wm.webhook_events_table_name,
    wm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    ism.prefix AS signing_secrets_prefix,
    ism.entity_field AS signing_secrets_entity_field,
    iss.schema_name AS signing_secrets_schema,
    nsm.namespaces_table_name,
    nsm.entity_field AS namespaces_entity_field,
    nss.schema_name AS namespaces_schema,
    wm.function_invocation_module_id
FROM metaschema_modules_public.webhook_module AS wm
    LEFT JOIN metaschema_public.schema ps ON ps.id = wm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = wm.private_schema_id
    LEFT JOIN metaschema_modules_public.infra_secrets_module ism ON ism.id = wm.infra_secrets_module_id
    LEFT JOIN metaschema_public.schema iss ON iss.id = ism.schema_id
    LEFT JOIN metaschema_modules_public.namespace_module nsm ON nsm.id = wm.namespace_module_id
    LEFT JOIN metaschema_public.schema nss ON nss.id = nsm.schema_id
WHERE ($1 IS NULL OR wm.database_id = $1)
  AND ($2 IS NULL OR wm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.webhook_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
