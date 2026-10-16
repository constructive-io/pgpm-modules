-- Deploy schemas/function_resolution/procedures/oauth_requests_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/oauth_requests_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- oauth_requests_module_registrations: the oauth_requests_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.oauth_requests_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    prefix text,
    private_schema text
) AS $$
SELECT
    orm.database_id,
    (orm.database_id = app_scope.platform_database_id()) AS platform_owned,
    orm.scope,
    orm.entity_field,
    orm.prefix,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.oauth_requests_module AS orm
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = orm.private_schema_id
WHERE orm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.oauth_requests_module_registrations(uuid) FROM PUBLIC;

COMMIT;
