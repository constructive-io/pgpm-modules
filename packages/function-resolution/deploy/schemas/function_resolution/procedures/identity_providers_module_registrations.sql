-- Deploy schemas/function_resolution/procedures/identity_providers_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/identity_providers_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- identity_providers_module_registrations: the identity_providers_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.identity_providers_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    public_schema text,
    private_schema text,
    providers_table_name text
) AS $$
SELECT
    ipm.database_id,
    (ipm.database_id = app_scope.platform_database_id()) AS platform_owned,
    ipm.scope,
    ipm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    providers_t.name AS providers_table_name
FROM metaschema_modules_public.identity_providers_module AS ipm
    LEFT JOIN metaschema_public.schema ps ON ps.id = ipm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = ipm.private_schema_id
    LEFT JOIN metaschema_public.table providers_t
    ON providers_t.id = ipm.table_id AND ipm.table_id <> uuid_nil()
WHERE ipm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.identity_providers_module_registrations(uuid) FROM PUBLIC;

COMMIT;
